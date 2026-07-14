<?php

namespace App\Services;

use App\Models\ProductionBatch;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class ProductionAnalyticsService
{
    /**
     * Return the full analytics report for produced items in the given date range.
     *
     * Cached: 5 minutes when the period includes today, 60 minutes for purely historical ranges.
     */
    public function getReport(string $from, string $to, string $trendBy = 'day'): array
    {
        $ttl      = $this->resolveTtl($to);
        $cacheKey = "analytics:production:{$from}:{$to}:{$trendBy}";

        return Cache::remember($cacheKey, $ttl, function () use ($from, $to, $trendBy): array {
            return [
                'summary'    => $this->querySummary($from, $to),
                'trend'      => $this->queryTrend($from, $to, $trendBy),
                'by_type'    => $this->queryByType($from, $to),
                'by_color'   => $this->queryByColor($from, $to),
                'by_size'    => $this->queryBySize($from, $to),
                'by_quality' => $this->queryByQuality($from, $to),
                'by_edge'    => $this->queryByEdge($from, $to),
            ];
        });
    }

    // ─── Private helpers ─────────────────────────────────────────────────────

    /**
     * Base query builder: production_batch_items for non-cancelled batches in the period.
     * Joins: production_batch_items → production_batches → product_variants → product_colors → products
     */
    private function baseQuery(string $from, string $to)
    {
        return DB::table('production_batch_items')
            ->join('production_batches', 'production_batches.id', '=', 'production_batch_items.production_batch_id')
            ->join('product_variants', 'product_variants.id', '=', 'production_batch_items.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->where('production_batches.status', '!=', ProductionBatch::STATUS_CANCELLED)
            ->whereBetween(DB::raw('DATE(production_batches.planned_datetime)'), [$from, $to])
            ->whereNull('products.deleted_at');
    }

    private function querySummary(string $from, string $to): array
    {
        $row = $this->baseQuery($from, $to)
            ->selectRaw('COUNT(DISTINCT production_batches.id) as total_batches, COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_produced')
            ->first();

        return [
            'total_batches'  => (int) ($row->total_batches ?? 0),
            'total_produced' => (int) ($row->total_produced ?? 0),
        ];
    }

    private function queryTrend(string $from, string $to, string $trendBy): array
    {
        $dateFormat = match ($trendBy) {
            'week'  => '%Y-%u',
            'month' => '%Y-%m',
            default => '%Y-%m-%d',
        };

        $rows = $this->baseQuery($from, $to)
            ->selectRaw(
                "DATE_FORMAT(production_batches.planned_datetime, '{$dateFormat}') as period_label,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity"
            )
            ->groupByRaw("DATE_FORMAT(production_batches.planned_datetime, '{$dateFormat}')")
            ->orderByRaw("DATE_FORMAT(production_batches.planned_datetime, '{$dateFormat}')")
            ->get();

        return $rows->map(fn ($r) => [
            'label'          => $r->period_label,
            'batches_count'  => (int) $r->batches_count,
            'total_quantity' => (int) $r->total_quantity,
        ])->all();
    }

    private function queryByType(string $from, string $to): array
    {
        $total = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->selectRaw(
                'product_types.id,
                 COALESCE(product_types.type, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('product_types.id', 'product_types.type')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryByColor(string $from, string $to): array
    {
        $total = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->selectRaw(
                'colors.id,
                 COALESCE(colors.name, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('colors.id', 'colors.name')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryBySize(string $from, string $to): array
    {
        $total = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
            ->selectRaw(
                'product_sizes.id,
                 CASE
                     WHEN product_sizes.id IS NOT NULL
                     THEN CONCAT(product_sizes.width, "x", product_sizes.length)
                     ELSE ?
                 END as name,
                 product_sizes.width,
                 product_sizes.length,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity',
                ['O\'lchamsiz']
            )
            ->groupBy('product_sizes.id', 'product_sizes.width', 'product_sizes.length')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryByQuality(string $from, string $to): array
    {
        $total = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->selectRaw(
                'product_qualities.id,
                 COALESCE(product_qualities.quality_name, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('product_qualities.id', 'product_qualities.quality_name')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryByEdge(string $from, string $to): array
    {
        $total = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_edges', 'product_edges.id', '=', 'product_variants.product_edge_id')
            ->selectRaw(
                'product_edges.id,
                 COALESCE(product_edges.title, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('product_edges.id', 'product_edges.title')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    private function totalProduced(string $from, string $to): int
    {
        return (int) $this->baseQuery($from, $to)
            ->selectRaw('COALESCE(SUM(production_batch_items.produced_quantity), 0) as total')
            ->value('total');
    }

    private function appendPercentage($rows, int $total): array
    {
        return $rows->map(function ($row) use ($total): array {
            $qty = (int) $row->total_quantity;
            return [
                'id'             => $row->id,
                'name'           => $row->name,
                'batches_count'  => (int) $row->batches_count,
                'total_quantity' => $qty,
                'percentage'     => $total > 0 ? round(($qty / $total) * 100, 1) : 0.0,
            ];
        })->all();
    }

    /**
     * 5 min TTL if the period includes today; 60 min otherwise (historical data won't change).
     */
    private function resolveTtl(string $to): int
    {
        $toDate = Carbon::parse($to)->startOfDay();
        $today  = Carbon::today();

        return $toDate->gte($today) ? 300 : 3600;
    }
}
