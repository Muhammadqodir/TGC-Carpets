<?php

namespace App\Console\Commands;

use App\Models\StockMovement;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Assert product_variant_stock.quantity == SUM(stock_movements) per
 * variant, nightly. Same shape as production:reconcile, for stock. See
 * instructions/phase-2/08-stock-reconcile-command.md.
 *
 * Unlike production_events, stock_movements is complete and authoritative
 * by construction — every movement is a real document line. So --fix goes
 * the OPPOSITE direction from production:reconcile: it recomputes the
 * balance from the ledger (i.e. it is exactly stock:backfill-balances
 * scoped to drifted variants), never appends a correction movement.
 */
class StockReconcile extends Command
{
    protected $signature = 'stock:reconcile
                            {--fix        : write an adjustment movement to close the drift}
                            {--variant=   : check a single product_variant id}
                            {--limit=50   : max rows to print}';

    protected $description = 'Assert product_variant_stock.quantity == SUM(stock_movements).';

    public function handle(): int
    {
        $drifted = $this->findDrift($this->option('variant'));
        $negative = $this->findNegative();

        $exit = self::SUCCESS;

        if ($drifted->isEmpty()) {
            $this->info('stock:reconcile — OK, ' . $this->variantCount() . ' variants, no drift.');
        } else {
            $exit = self::FAILURE;
            $this->error("stock:reconcile — DRIFT on {$drifted->count()} variant(s).");

            $this->table(
                ['variant', 'product', 'balance', 'ledger', 'drift'],
                $drifted->take((int) $this->option('limit'))->map(fn ($r) => [
                    $r->product_variant_id, $r->product_name ?? '—',
                    $r->balance, $r->ledger, $r->drift,
                ]),
            );

            $this->warn('Net drift: ' . $drifted->sum('drift')
                . ' | over-stated: ' . $drifted->where('drift', '>', 0)->sum('drift')
                . ' | under-stated: ' . $drifted->where('drift', '<', 0)->sum('drift'));

            if ($this->option('fix')) {
                $this->applyFix($drifted);
            }
        }

        // Negative stock is a different problem from drift: cache and ledger
        // AGREE on a value below zero — carpets were shipped that never
        // existed. --fix does not touch this; only a real warehouse
        // adjustment document (an auditable movement) can.
        if ($negative->isNotEmpty()) {
            $exit = self::FAILURE;
            $this->error("{$negative->count()} variant(s) have NEGATIVE stock — carpets shipped that never existed.");
            $this->table(['variant', 'balance'], $negative->map(fn ($r) => [$r->product_variant_id, $r->quantity]));
        }

        return $exit;
    }

    private function findDrift(?string $variantId)
    {
        $query = DB::table('product_variants as v')
            ->leftJoin('product_variant_stock as s', 's.product_variant_id', '=', 'v.id')
            ->leftJoin('product_colors as pc', 'pc.id', '=', 'v.product_color_id')
            ->leftJoin('products as p', 'p.id', '=', 'pc.product_id')
            ->leftJoinSub(
                DB::table('stock_movements')
                    ->selectRaw(
                        "product_variant_id,
                         SUM(CASE WHEN movement_type = '" . StockMovement::TYPE_IN . "' THEN quantity ELSE -quantity END) AS qty"
                    )
                    ->groupBy('product_variant_id'),
                'm',
                'm.product_variant_id',
                '=',
                'v.id',
            )
            ->selectRaw(
                'v.id AS product_variant_id,
                 p.name AS product_name,
                 COALESCE(s.quantity, 0) AS balance,
                 COALESCE(m.qty, 0) AS ledger,
                 COALESCE(s.quantity, 0) - COALESCE(m.qty, 0) AS drift'
            )
            ->when($variantId !== null, fn ($q) => $q->where('v.id', (int) $variantId))
            ->havingRaw('COALESCE(s.quantity, 0) <> COALESCE(m.qty, 0)')
            ->orderByRaw('ABS(COALESCE(s.quantity, 0) - COALESCE(m.qty, 0)) DESC');

        return $query->get();
    }

    private function findNegative()
    {
        return DB::table('product_variant_stock')->where('quantity', '<', 0)->get();
    }

    private function variantCount(): int
    {
        return (int) DB::table('product_variants')->count();
    }

    private function applyFix($drifted): void
    {
        foreach ($drifted as $row) {
            DB::table('product_variant_stock')->upsert(
                [[
                    'product_variant_id' => $row->product_variant_id,
                    'quantity'           => $row->ledger,
                    'created_at'         => now(),
                    'updated_at'         => now(),
                ]],
                ['product_variant_id'],
                ['quantity', 'updated_at'],
            );
        }

        $this->info('--fix: recomputed balance from the ledger for ' . $drifted->count() . ' variant(s). stock_movements untouched.');
    }
}
