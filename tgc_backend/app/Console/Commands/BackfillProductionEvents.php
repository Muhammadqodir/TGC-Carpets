<?php

namespace App\Console\Commands;

use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * One synthetic opening event per existing production_batch_item, so the
 * ledger reconciles from day one. See
 * instructions/phase-2/03-backfill-opening-events.md.
 *
 * The per-event history for the past never existed — this writes a single
 * lump event per item, dated with the best available proxy
 * (batch.completed_datetime > batch.started_datetime > item.created_at),
 * tagged reason='backfill' so it can always be told apart from measured
 * history.
 *
 * Idempotent: skips items that already have a reason='backfill' event, so
 * it is safe to interrupt and re-run.
 *
 * IMPORTANT — read instructions/phase-2/03's "ordering trap" before running
 * this against a database where step 01 has already been live for a while:
 * this command backfills the item's CURRENT produced/defect_quantity. If
 * step 01 has been live and printing labels for days before this runs, the
 * counter already includes that real activity and the opening event would
 * double-count it. Run this in the same maintenance window as step 01's
 * deploy, before any label is printed against the new code.
 */
class BackfillProductionEvents extends Command
{
    protected $signature = 'production:backfill-events
                            {--chunk=500 : rows per batch}
                            {--dry-run  : report only, write nothing}';

    protected $description = 'Write one synthetic opening event per production_batch_item (idempotent).';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $chunk  = (int) $this->option('chunk');
        $now    = now();
        $written = 0;
        $skipped = 0;

        ProductionBatchItem::query()
            ->select('production_batch_items.*')
            ->addSelect([
                'batch_completed' => ProductionBatch::select('completed_datetime')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
                'batch_started' => ProductionBatch::select('started_datetime')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
                'batch_created_by' => ProductionBatch::select('created_by')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
            ])
            ->where(function ($q) {
                $q->where('produced_quantity', '>', 0)
                    ->orWhere('defect_quantity', '>', 0);
            })
            ->whereNotExists(function ($q) {
                $q->select(DB::raw(1))
                    ->from('production_events')
                    ->whereColumn('production_events.production_batch_item_id', 'production_batch_items.id')
                    ->where('production_events.reason', 'backfill');
            })
            ->orderBy('production_batch_items.id')
            ->chunkById($chunk, function ($items) use (&$written, &$skipped, $dryRun, $now): void {
                $rows = [];

                foreach ($items as $item) {
                    $occurredAt = $item->batch_completed
                        ?? $item->batch_started
                        ?? $item->created_at;

                    if ($occurredAt === null) {
                        $this->warn("item {$item->id}: no usable timestamp, skipped");
                        $skipped++;
                        continue;
                    }

                    if ($item->produced_quantity > 0) {
                        $rows[] = [
                            'production_batch_item_id' => $item->id,
                            'event_type'      => ProductionEvent::TYPE_PRODUCED,
                            'quantity'        => (int) $item->produced_quantity,
                            'occurred_at'     => $occurredAt,
                            'user_id'         => $item->batch_created_by,
                            'idempotency_key' => null,
                            'reason'          => 'backfill',
                            'created_at'      => $now,
                        ];
                    }

                    if ($item->defect_quantity > 0) {
                        $rows[] = [
                            'production_batch_item_id' => $item->id,
                            'event_type'      => ProductionEvent::TYPE_DEFECT,
                            'quantity'        => (int) $item->defect_quantity,
                            'occurred_at'     => $occurredAt,
                            'user_id'         => $item->batch_created_by,
                            'idempotency_key' => null,
                            'reason'          => 'backfill',
                            'created_at'      => $now,
                        ];
                    }
                }

                if (! $dryRun && $rows !== []) {
                    DB::table('production_events')->insert($rows);
                }

                $written += count($rows);
                $this->info("… {$written} events prepared");
            }, 'production_batch_items.id');

        $this->info(($dryRun ? '[dry-run] would write ' : 'wrote ') . "{$written} events, skipped {$skipped}");

        return self::SUCCESS;
    }
}
