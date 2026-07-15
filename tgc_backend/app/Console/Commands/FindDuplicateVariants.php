<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Read-only. Phase-1 step 05, stage 2 — find the duplicate-identity groups
 * that instructions/phase-1/05-variant-unique-constraint.md needs a human
 * decision on before anything merges. Safe to run against production at any
 * time; it writes nothing.
 */
class FindDuplicateVariants extends Command
{
    protected $signature = 'variants:find-duplicates';

    protected $description = 'Report product_variants groups that share (color, size, edge) or (color, size) — read-only.';

    public function handle(): int
    {
        $this->info('── Strict identity groups: (color, size, edge) — MySQL GROUP BY treats NULL edge as its own value ──');

        $strict = DB::table('product_variants')
            ->select('product_color_id', 'product_size_id', 'product_edge_id')
            ->selectRaw('COUNT(*) AS n')
            ->selectRaw('GROUP_CONCAT(id ORDER BY id) AS variant_ids')
            ->selectRaw('GROUP_CONCAT(sku_code ORDER BY id SEPARATOR \' | \') AS skus')
            ->groupBy('product_color_id', 'product_size_id', 'product_edge_id')
            ->havingRaw('COUNT(*) > 1')
            ->orderByDesc('n')
            ->get();

        if ($strict->isEmpty()) {
            $this->line('  (none)');
        } else {
            $this->table(
                ['color_id', 'size_id', 'edge_id', 'n', 'variant_ids', 'skus'],
                $strict->map(fn ($r) => [$r->product_color_id, $r->product_size_id, $r->product_edge_id, $r->n, $r->variant_ids, $r->skus])
            );
        }

        $this->newLine();
        $this->info('── (color, size) view — catches NULL-vs-R splits the strict view separates into different groups ──');

        $bySize = DB::table('product_variants')
            ->select('product_color_id', 'product_size_id')
            ->selectRaw('COUNT(*) AS n')
            ->selectRaw('GROUP_CONCAT(id ORDER BY id) AS variant_ids')
            ->selectRaw('GROUP_CONCAT(COALESCE(product_edge_id, \'NULL\') ORDER BY id) AS edges')
            ->groupBy('product_color_id', 'product_size_id')
            ->havingRaw('COUNT(*) > 1')
            ->orderByDesc('n')
            ->get();

        if ($bySize->isEmpty()) {
            $this->line('  (none)');
        } else {
            $this->table(
                ['color_id', 'size_id', 'n', 'variant_ids', 'edges'],
                $bySize->map(fn ($r) => [$r->product_color_id, $r->product_size_id, $r->n, $r->variant_ids, $r->edges])
            );
        }

        $this->newLine();
        $this->info('── NULL-edge variants carrying stock — the sharp end ──');

        $nullEdgeStock = DB::table('product_variants as pv')
            ->leftJoin('stock_movements as sm', 'sm.product_variant_id', '=', 'pv.id')
            ->whereNull('pv.product_edge_id')
            ->select('pv.id', 'pv.product_color_id', 'pv.product_size_id', 'pv.sku_code')
            ->selectRaw(
                "COALESCE(SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END), 0)"
                . " - COALESCE(SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END), 0) AS stock"
            )
            ->groupBy('pv.id', 'pv.product_color_id', 'pv.product_size_id', 'pv.sku_code')
            ->havingRaw('stock <> 0')
            ->get();

        if ($nullEdgeStock->isEmpty()) {
            $this->line('  (none)');
        } else {
            $this->table(
                ['id', 'color_id', 'size_id', 'sku', 'stock'],
                $nullEdgeStock->map(fn ($r) => [$r->id, $r->product_color_id, $r->product_size_id, $r->sku_code, $r->stock])
            );
        }

        $this->newLine();
        $this->comment(
            'Judgement call, not automatable: a {NULL, R} group is probably one carpet split by the '
            . 'step-04 bug and should merge. A {R, S} group is two genuinely different products and '
            . 'must not. Take this output to whoever knows the products before running '
            . 'variants:merge-duplicates. See instructions/phase-1/05-variant-unique-constraint.md.'
        );

        return self::SUCCESS;
    }
}
