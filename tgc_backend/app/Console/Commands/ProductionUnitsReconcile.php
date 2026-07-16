<?php

namespace App\Console\Commands;

use App\Models\ProductionUnit;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Assert production_batch_items.produced_quantity ==
 * COUNT(production_units WHERE status IN good/received/shipped) per item.
 *
 * This is the value of the whole file even if the rollout stops after
 * this command: it tells you, for the first time, how far the counter
 * has drifted from reality. Expect the unit count to be LOWER than
 * produced_quantity — the gap is the accumulated reprints the old blind
 * increment() could never see. See
 * instructions/phase-3/02-production-units-serials.md.
 *
 * Read-only. There is no --fix here, deliberately: unlike the phase-2
 * reconcile commands (where the log is source of truth and the cache can
 * be corrected), during the dual-run produced_quantity is STILL the
 * counter of record — see step 5 of the instruction file's rollout order.
 * "Fixing" it against the unit count before that switch has happened
 * would be fixing the trustworthy number to match the untrustworthy one.
 */
class ProductionUnitsReconcile extends Command
{
    protected $signature = 'production:reconcile-units
                            {--item=    : check a single production_batch_item id}
                            {--limit=50 : max rows to print}';

    protected $description = 'Compare produced_quantity against real ProductionUnit counts (read-only).';

    public function handle(): int
    {
        $producedStatuses = implode(',', array_map(
            fn ($s) => "'{$s}'",
            ProductionUnit::PRODUCED_STATUSES,
        ));

        $inner = DB::table('production_batch_items as i')
            ->leftJoin('production_units as u', 'u.production_batch_item_id', '=', 'i.id')
            ->selectRaw(
                "i.id,
                 i.production_batch_id,
                 i.produced_quantity,
                 COALESCE(SUM(CASE WHEN u.status IN ({$producedStatuses}) THEN 1 ELSE 0 END), 0) AS unit_count,
                 COALESCE(SUM(CASE WHEN u.backfilled_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS backfilled_count,
                 COALESCE(SUM(CASE WHEN u.reprint_count > 0 THEN u.reprint_count ELSE 0 END), 0) AS total_reprints,
                 i.produced_quantity
                   - COALESCE(SUM(CASE WHEN u.status IN ({$producedStatuses}) THEN 1 ELSE 0 END), 0) AS drift"
            )
            ->where('i.produced_quantity', '>', 0)
            ->when($this->option('item') !== null, fn ($q) => $q->where('i.id', (int) $this->option('item')))
            ->groupBy('i.id', 'i.production_batch_id', 'i.produced_quantity');

        // MariaDB (unlike MySQL) rejects HAVING on an alias that is itself
        // derived from a group function in the same query — wrap the
        // aggregation in a subquery so 'drift' is a plain derived-table
        // column by the time it's filtered/ordered.
        $drifted = DB::table(DB::raw("({$inner->toSql()}) as t"))
            ->mergeBindings($inner)
            ->whereRaw('drift <> 0')
            ->orderByRaw('ABS(drift) DESC')
            ->get();
        $totalItems = DB::table('production_batch_items')->where('produced_quantity', '>', 0)->count();

        if ($drifted->isEmpty()) {
            $this->info("production:reconcile-units — OK, {$totalItems} items with production, no drift.");

            return self::SUCCESS;
        }

        $this->warn("production:reconcile-units — drift on {$drifted->count()} of {$totalItems} item(s). "
            . 'A positive drift (produced_quantity > unit_count) is the accumulated reprint/double-count gap this table exists to close.');

        $this->table(
            ['item', 'batch', 'produced_quantity', 'unit_count', 'drift', 'backfilled', 'reprints'],
            $drifted->take((int) $this->option('limit'))->map(fn ($r) => [
                $r->id, $r->production_batch_id, $r->produced_quantity,
                $r->unit_count, $r->drift, $r->backfilled_count, $r->total_reprints,
            ]),
        );

        $this->warn('Total drift: ' . $drifted->sum('drift') . ' unit(s) across all items.');

        // Non-zero exit so a scheduled run surfaces via the normal
        // schedule:run failure channel — see routes/console.php.
        return self::FAILURE;
    }
}
