<?php

namespace App\Console\Commands;

use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * One synthetic ProductionUnit per already-counted carpet
 * (produced_quantity of them), so COUNT(*) matches produced_quantity on
 * day one. See instructions/phase-3/02-production-units-serials.md.
 *
 * These backfilled rows do NOT correspond to any physical label — the
 * carpets they represent were labelled before this table existed, with
 * the batch-line QR (P{batchId} I{itemId} / PB.. PBI..), which is still
 * perfectly scannable — see ProductionBatchController::scanItem(). Never
 * treat a backfilled row (backfilled_at IS NOT NULL) as traceable to a
 * physical unit; it exists only to make the count reconcile.
 *
 * Idempotent: an item that already has any backfilled units is skipped
 * entirely, so this is safe to interrupt and re-run. Run in the same
 * maintenance window as this migration, before any real print — a print
 * that lands between the migration and this command is invisible to it
 * (produced_quantity would already include it, so the backfill for that
 * item would double-count). See BackfillProductionEvents's identical
 * ordering trap for the established precedent on this codebase.
 */
class BackfillProductionUnits extends Command
{
    protected $signature = 'production:backfill-units
                            {--chunk=200 : batch items processed per chunk}
                            {--dry-run   : report only, write nothing}';

    protected $description = 'Write one synthetic ProductionUnit per already-counted carpet (idempotent).';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $chunk  = (int) $this->option('chunk');
        $itemsDone = 0;
        $unitsWritten = 0;

        ProductionBatchItem::query()
            ->select('production_batch_items.*')
            ->addSelect([
                'batch_completed'  => ProductionBatch::select('completed_datetime')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
                'batch_started'    => ProductionBatch::select('started_datetime')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
                'batch_created_by' => ProductionBatch::select('created_by')
                    ->whereColumn('id', 'production_batch_items.production_batch_id'),
            ])
            ->where('produced_quantity', '>', 0)
            ->whereNotExists(function ($q) {
                $q->select(DB::raw(1))
                    ->from('production_units')
                    ->whereColumn('production_units.production_batch_item_id', 'production_batch_items.id')
                    ->whereNotNull('production_units.backfilled_at');
            })
            ->orderBy('production_batch_items.id')
            ->chunkById($chunk, function ($items) use (&$itemsDone, &$unitsWritten, $dryRun): void {
                foreach ($items as $item) {
                    $printedAt = $item->batch_completed ?? $item->batch_started ?? $item->created_at;
                    $printedBy = $item->batch_created_by;

                    if ($printedAt === null || $printedBy === null) {
                        $this->warn("item {$item->id}: no usable timestamp/user, skipped");
                        continue;
                    }

                    if ($dryRun) {
                        $unitsWritten += (int) $item->produced_quantity;
                        continue;
                    }

                    $now = now();

                    DB::transaction(function () use ($item, $printedAt, $printedBy, $now, &$unitsWritten): void {
                        for ($i = 0; $i < (int) $item->produced_quantity; $i++) {
                            $unit = ProductionUnit::create([
                                'production_batch_item_id' => $item->id,
                                'serial'                   => 'PENDING',
                                'printed_by'               => $printedBy,
                                'printed_at'                => $printedAt,
                                'status'                    => ProductionUnit::STATUS_GOOD,
                                'backfilled_at'             => $now,
                            ]);
                            $unit->update(['serial' => sprintf('TGC-U-%08d', $unit->id)]);
                            $unitsWritten++;
                        }
                    });
                }

                $itemsDone += count($items);
                $this->info("… {$itemsDone} items processed, {$unitsWritten} units written");
            }, 'production_batch_items.id');

        $this->info(($dryRun ? '[dry-run] would write ' : 'wrote ') . "{$unitsWritten} units across {$itemsDone} items.");

        return self::SUCCESS;
    }
}
