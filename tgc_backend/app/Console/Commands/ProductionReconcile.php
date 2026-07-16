<?php

namespace App\Console\Commands;

use App\Models\ProductionEvent;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Assert production_batch_items.produced_quantity/defect_quantity == the
 * corresponding SUM(production_events.quantity). See
 * instructions/phase-2/06-production-reconcile-command.md.
 *
 * This is the alerting mechanism for the whole cache-plus-log design in
 * phase 2 — a cache that is never checked against its source is just a
 * second number that happens to be nearby.
 */
class ProductionReconcile extends Command
{
    protected $signature = 'production:reconcile
                            {--fix       : write correction events to close the drift}
                            {--item=     : check a single production_batch_item id}
                            {--limit=50  : max rows to print}';

    protected $description = 'Assert production_batch_items counters == SUM(production_events).';

    public function handle(): int
    {
        $drifted = $this->findDrift($this->option('item'));

        if ($drifted->isEmpty()) {
            $this->info('production:reconcile — OK, ' . $this->itemCount() . ' items, no drift.');

            return self::SUCCESS;
        }

        $this->error("production:reconcile — DRIFT on {$drifted->count()} item(s).");

        $this->table(
            ['item', 'batch', 'produced (cache/log/drift)', 'defect (cache/log/drift)'],
            $drifted->take((int) $this->option('limit'))->map(fn ($r) => [
                $r->id,
                $r->production_batch_id,
                "{$r->produced_quantity} / {$r->produced_log} / {$r->produced_drift}",
                "{$r->defect_quantity} / {$r->defect_log} / {$r->defect_drift}",
            ]),
        );

        $this->warn('Totals — produced drift: ' . $drifted->sum('produced_drift')
            . ', defect drift: ' . $drifted->sum('defect_drift'));

        if ($this->option('fix')) {
            $this->applyFix($drifted);
        }

        // Non-zero exit = the scheduler / monitoring treats this as a failure.
        return self::FAILURE;
    }

    private function findDrift(?string $itemId)
    {
        $producedTypes = implode(',', array_map(
            fn ($t) => "'{$t}'",
            ProductionEvent::PRODUCED_TYPES,
        ));

        $inner = DB::table('production_batch_items as i')
            ->leftJoin('production_events as e', 'e.production_batch_item_id', '=', 'i.id')
            ->selectRaw(
                "i.id,
                 i.production_batch_id,
                 i.produced_quantity,
                 COALESCE(SUM(CASE WHEN e.event_type IN ({$producedTypes})
                                   THEN e.quantity END), 0) AS produced_log,
                 i.produced_quantity
                   - COALESCE(SUM(CASE WHEN e.event_type IN ({$producedTypes})
                                       THEN e.quantity END), 0) AS produced_drift,
                 i.defect_quantity,
                 COALESCE(SUM(CASE WHEN e.event_type = 'defect' THEN e.quantity END), 0) AS defect_log,
                 i.defect_quantity
                   - COALESCE(SUM(CASE WHEN e.event_type = 'defect' THEN e.quantity END), 0) AS defect_drift"
            )
            ->when($itemId !== null, fn ($q) => $q->where('i.id', (int) $itemId))
            ->groupBy('i.id', 'i.production_batch_id', 'i.produced_quantity', 'i.defect_quantity');

        // MariaDB (unlike MySQL) rejects HAVING on an alias that is itself
        // derived from a group function in the same query — wrap the
        // aggregation in a subquery so produced_drift/defect_drift are
        // plain derived-table columns by the time they're filtered/ordered.
        return DB::table(DB::raw("({$inner->toSql()}) as t"))
            ->mergeBindings($inner)
            ->whereRaw('produced_drift <> 0 OR defect_drift <> 0')
            ->orderByRaw('ABS(produced_drift) + ABS(defect_drift) DESC')
            ->get();
    }

    private function itemCount(): int
    {
        return (int) DB::table('production_batch_items')->count();
    }

    private function applyFix($drifted): void
    {
        $userId = config('reconcile.system_user_id');

        if ($userId === null) {
            $this->error('reconcile.system_user_id (RECONCILE_SYSTEM_USER_ID) is not set — cannot --fix without '
                . 'attributing the correction to a real user. Set it and re-run.');

            return;
        }

        $userId = (int) $userId;

        foreach ($drifted as $row) {
            DB::transaction(function () use ($row, $userId): void {
                if ($row->produced_drift != 0) {
                    ProductionEvent::create([
                        'production_batch_item_id' => $row->id,
                        'event_type'  => ProductionEvent::TYPE_CORRECTION,
                        'quantity'    => $row->produced_drift,   // signed: closes log → cache
                        'occurred_at' => now(),
                        'user_id'     => $userId,
                        'reason'      => 'reconcile: closing produced drift of ' . $row->produced_drift,
                        'created_at'  => now(),
                    ]);
                }

                if ($row->defect_drift != 0) {
                    ProductionEvent::create([
                        'production_batch_item_id' => $row->id,
                        'event_type'  => ProductionEvent::TYPE_DEFECT,
                        'quantity'    => $row->defect_drift,
                        'occurred_at' => now(),
                        'user_id'     => $userId,
                        'reason'      => 'reconcile: closing defect drift of ' . $row->defect_drift,
                        'created_at'  => now(),
                    ]);
                }
            });
        }

        $this->info('--fix: wrote correction/defect events for ' . $drifted->count() . ' item(s). Counters unchanged.');
    }
}
