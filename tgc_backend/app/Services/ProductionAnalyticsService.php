<?php

namespace App\Services;

use App\Models\ProductionBatch;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class ProductionAnalyticsService
{
    /** Raw expression: sqm produced by a row, in square meters (width/length are stored in cm). */
    private const SQM_EXPR = 'COALESCE(SUM(production_batch_items.produced_quantity * product_sizes.width * product_sizes.length), 0) / 10000';

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
     * Base query builder: only items that have actually been produced (produced_quantity > 0),
     * for non-cancelled batches, whose produced_quantity was last touched within the period
     * (production_batch_items.updated_at — that's when label printing bumps the counter).
     *
     * Joins: production_batch_items → production_batches → product_variants → product_colors
     *        → products, plus a left join to product_sizes for sqm calculations.
     */
    private function baseQuery(string $from, string $to)
    {
        return DB::table('production_batch_items')
            ->join('production_batches', 'production_batches.id', '=', 'production_batch_items.production_batch_id')
            ->join('product_variants', 'product_variants.id', '=', 'production_batch_items.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
            ->where('production_batches.status', '!=', ProductionBatch::STATUS_CANCELLED)
            ->where('production_batch_items.produced_quantity', '>', 0)
            ->whereBetween(DB::raw('DATE(production_batch_items.updated_at)'), [$from, $to])
            ->whereNull('products.deleted_at');
    }

    private function querySummary(string $from, string $to): array
    {
        $row = $this->baseQuery($from, $to)
            ->selectRaw(
                'COUNT(DISTINCT production_batches.id) as total_batches,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_produced,
                 ' . self::SQM_EXPR . ' as total_sqm'
            )
            ->first();

        return [
            'total_batches'  => (int) ($row->total_batches ?? 0),
            'total_produced' => (int) ($row->total_produced ?? 0),
            'total_sqm'      => round((float) ($row->total_sqm ?? 0), 2),
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
                "DATE_FORMAT(production_batch_items.updated_at, '{$dateFormat}') as period_label,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity,
                 " . self::SQM_EXPR . ' as total_sqm'
            )
            ->groupByRaw("DATE_FORMAT(production_batch_items.updated_at, '{$dateFormat}')")
            ->orderByRaw("DATE_FORMAT(production_batch_items.updated_at, '{$dateFormat}')")
            ->get();

        return $rows->map(fn ($r) => [
            'label'          => $r->period_label,
            'batches_count'  => (int) $r->batches_count,
            'total_quantity' => (int) $r->total_quantity,
            'total_sqm'      => round((float) $r->total_sqm, 2),
        ])->all();
    }

    private function queryByType(string $from, string $to): array
    {
        $totalQty = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->selectRaw(
                'product_types.id,
                 COALESCE(product_types.type, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity,
                 ' . self::SQM_EXPR . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('product_types.id', 'product_types.type')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryByColor(string $from, string $to): array
    {
        $totalQty = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->selectRaw(
                'colors.id,
                 COALESCE(colors.name, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity,
                 ' . self::SQM_EXPR . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('colors.id', 'colors.name')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryBySize(string $from, string $to): array
    {
        $totalQty = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
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
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity,
                 ' . self::SQM_EXPR . ' as total_sqm',
                ['O\'lchamsiz']
            )
            ->groupBy('product_sizes.id', 'product_sizes.width', 'product_sizes.length')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryByQuality(string $from, string $to): array
    {
        $totalQty = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->selectRaw(
                'product_qualities.id,
                 COALESCE(product_qualities.quality_name, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity,
                 ' . self::SQM_EXPR . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('product_qualities.id', 'product_qualities.quality_name')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryByEdge(string $from, string $to): array
    {
        $totalQty = $this->totalProduced($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_edges', 'product_edges.id', '=', 'product_variants.product_edge_id')
            ->selectRaw(
                'product_edges.id,
                 COALESCE(product_edges.title, ?) as name,
                 COUNT(DISTINCT production_batches.id) as batches_count,
                 COALESCE(SUM(production_batch_items.produced_quantity), 0) as total_quantity,
                 ' . self::SQM_EXPR . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('product_edges.id', 'product_edges.title')
            ->orderByRaw('SUM(production_batch_items.produced_quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    private function totalProduced(string $from, string $to): int
    {
        return (int) $this->baseQuery($from, $to)
            ->selectRaw('COALESCE(SUM(production_batch_items.produced_quantity), 0) as total')
            ->value('total');
    }

    private function appendPercentage($rows, int $totalQty): array
    {
        return $rows->map(function ($row) use ($totalQty): array {
            $qty = (int) $row->total_quantity;
            return [
                'id'             => $row->id,
                'name'           => $row->name,
                'batches_count'  => (int) $row->batches_count,
                'total_quantity' => $qty,
                'total_sqm'      => round((float) $row->total_sqm, 2),
                'percentage'     => $totalQty > 0 ? round(($qty / $totalQty) * 100, 1) : 0.0,
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
