<?php

namespace App\Console\Commands;

use App\Models\LabelReprint;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use App\Models\ProductionUnit;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Undo the carpets counted past a batch line's plan before print-label
 * stopped counting there. Seven lines on production (2026-09-17) were each one
 * carpet over, every time from a double click: two prints of the same line
 * within a second, both counted.
 *
 * For each extra carpet, in one transaction per line:
 *   - the newest non-backfilled production_unit becomes a label_reprints row
 *     (reason over_target) with the same printer and time, and is deleted, so
 *     production:reconcile-units still matches produced_quantity. Lines
 *     labelled before 2026-07-20 only have backfilled units, which name no
 *     real printer or time: one of those is deleted with no reprint row, rather
 *     than a row with an invented printer;
 *   - a 'correction' event of -1 is appended, so production:reconcile still
 *     matches the event log;
 *   - produced_quantity goes down by one.
 *
 * Lines whose extra carpets were already received into the warehouse are
 * skipped and reported: those need a person to decide what is physically there.
 * Dry run unless --apply is given.
 */
class FixOverTargetProduction extends Command
{
    protected $signature = 'production:fix-over-target
                            {--apply : write the corrections}
                            {--user= : id of the user the correction events are recorded under (required with --apply)}';

    protected $description = 'Turn carpets counted past a batch line plan back into recorded reprints.';

    public function handle(): int
    {
        $userId = (int) $this->option('user');
        if ($this->option('apply') && ! User::whereKey($userId)->exists()) {
            $this->error('--apply needs --user=<id> of an existing user to record the corrections under.');

            return self::FAILURE;
        }

        $lines = ProductionBatchItem::whereRaw('produced_quantity > planned_quantity - defect_quantity')
            ->orderBy('id')
            ->get();

        if ($lines->isEmpty()) {
            $this->info('No batch line is counted past its plan.');

            return self::SUCCESS;
        }

        $rows = [];
        foreach ($lines as $line) {
            $target = max(0, $line->planned_quantity - $line->defect_quantity);
            $extra  = $line->produced_quantity - $target;
            $note   = $this->option('apply') ? 'fixed' : 'would fix';

            if ($line->warehouse_received_quantity > $target) {
                $note = 'SKIPPED: warehouse already received more than the plan';
            } elseif ($this->option('apply')) {
                $note = $this->fix($line->id, $extra, $userId) ? 'fixed' : 'SKIPPED: not enough printed labels to convert';
            }

            $rows[] = [$line->id, $line->production_batch_id, $line->planned_quantity, $line->defect_quantity,
                $line->produced_quantity, $target, $extra, $line->warehouse_received_quantity, $note];
        }

        $this->table(['item', 'batch', 'planned', 'defect', 'produced', 'target', 'extra', 'received', 'result'], $rows);

        if (! $this->option('apply')) {
            $this->warn('Dry run. Re-run with --apply to write the corrections.');
        }

        return self::SUCCESS;
    }

    private function fix(int $lineId, int $extra, int $userId): bool
    {
        return DB::transaction(function () use ($lineId, $extra, $userId): bool {
            $line   = ProductionBatchItem::whereKey($lineId)->lockForUpdate()->first();
            $target = max(0, $line->planned_quantity - $line->defect_quantity);
            $extra  = min($extra, $line->produced_quantity - $target);

            // Real prints first, newest first; backfilled rows only after them.
            $units = ProductionUnit::where('production_batch_item_id', $line->id)
                ->orderByRaw('backfilled_at IS NOT NULL')
                ->orderByDesc('printed_at')
                ->orderByDesc('id')
                ->limit($extra)
                ->lockForUpdate()
                ->get();

            if ($extra <= 0 || $units->count() < $extra) {
                return false;
            }

            foreach ($units as $unit) {
                if (! $unit->isBackfilled()) {
                    LabelReprint::create([
                        'production_batch_item_id' => $line->id,
                        'printed_by'               => $unit->printed_by,
                        'printed_at'               => $unit->printed_at,
                        'reason'                   => LabelReprint::REASON_OVER_TARGET,
                    ]);
                }
                $unit->delete();
            }

            ProductionEvent::create([
                'production_batch_item_id' => $line->id,
                'event_type'               => ProductionEvent::TYPE_CORRECTION,
                'quantity'                 => -$extra,
                'occurred_at'              => now(),
                'user_id'                  => $userId,
                'reason'                   => 'production:fix-over-target — double-click prints past the plan became reprints',
                'created_at'               => now(),
            ]);

            $line->decrement('produced_quantity', $extra);

            return true;
        });
    }
}
