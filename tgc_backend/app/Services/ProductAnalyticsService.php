<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ProductAnalyticsService
{
    /**
     * Return the full analytics report for ordered products in the given date range.
     *
     * Cached: 5 minutes when the period includes today, 60 minutes for purely historical ranges.
     */
    public function getReport(string $from, string $to, string $trendBy = 'day'): array
    {
        $ttl    = $this->resolveTtl($to);
        $cacheKey = "analytics:products:{$from}:{$to}:{$trendBy}";

        return Cache::remember($cacheKey, $ttl, function () use ($from, $to, $trendBy): array {
            return [
                'summary'      => $this->querySummary($from, $to),
                'trend'        => $this->queryTrend($from, $to, $trendBy),
                'by_type'      => $this->queryByType($from, $to),
                'by_color'     => $this->queryByColor($from, $to),
                'by_size'      => $this->queryBySize($from, $to),
                'by_quality'   => $this->queryByQuality($from, $to),
                'by_edge'      => $this->queryByEdge($from, $to),
                'top_products' => $this->queryTopProducts($from, $to),
            ];
        });
    }

    /**
     * Return filtered top products with optional attribute filters and a configurable limit.
     * Each unique combination of filters gets its own cache entry.
     */
    public function getFilteredTopProducts(
        string $from,
        string $to,
        ?int $typeId,
        ?int $qualityId,
        ?int $colorId,
        ?int $sizeId,
        ?int $edgeId,
        int $limit = 10,
    ): array {
        $ttl = $this->resolveTtl($to);
        $cacheKey = "analytics:top-products:{$from}:{$to}:t{$typeId}:q{$qualityId}:c{$colorId}:s{$sizeId}:e{$edgeId}:l{$limit}";

        return Cache::remember($cacheKey, $ttl, function () use ($from, $to, $typeId, $qualityId, $colorId, $sizeId, $edgeId, $limit): array {
            $total = $this->filteredTotal($from, $to, $typeId, $qualityId, $colorId, $sizeId, $edgeId);

            $query = $this->baseQuery($from, $to)
                ->leftJoin('product_types',    'product_types.id',    '=', 'products.product_type_id')
                ->leftJoin('product_qualities','product_qualities.id','=', 'products.product_quality_id')
                ->selectRaw(
                    "products.id,
                     products.name,
                     COALESCE(product_types.type, 'Noma\'lum') as type_name,
                     COALESCE(product_qualities.quality_name, 'Noma\'lum') as quality_name,
                     COUNT(DISTINCT orders.id) as orders_count,
                     COALESCE(SUM(order_items.quantity), 0) as total_quantity"
                )
                ->groupBy('products.id', 'products.name', 'product_types.type', 'product_qualities.quality_name')
                ->orderByRaw('SUM(order_items.quantity) DESC')
                ->limit($limit);

            $this->applyFilters($query, $typeId, $qualityId, $colorId, $sizeId, $edgeId);

            $productRows = $query->get();

            if ($productRows->isEmpty()) return [];

            $productIds = $productRows->pluck('id')->filter()->toArray();

            // The breakdowns must carry the same filters as the parent query above —
            // otherwise percentages are computed from an unfiltered numerator over a
            // filtered denominator and can exceed 100%. See instructions/phase-0/10.
            $colorsByProduct = $this->applyFilters(
                $this->baseQuery($from, $to)->whereIn('products.id', $productIds),
                $typeId, $qualityId, $colorId, $sizeId, $edgeId,
            )
                ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
                ->selectRaw(
                    "products.id as product_id,
                     COALESCE(colors.name, 'Noma\'lum') as color_name,
                     product_colors.image as image,
                     COALESCE(SUM(order_items.quantity), 0) as quantity"
                )
                ->groupBy('products.id', 'colors.name', 'product_colors.image')
                ->orderByRaw('SUM(order_items.quantity) DESC')
                ->get()
                ->groupBy(fn ($r) => (string) $r->product_id);

            $sizesByProduct = $this->applyFilters(
                $this->baseQuery($from, $to)->whereIn('products.id', $productIds),
                $typeId, $qualityId, $colorId, $sizeId, $edgeId,
            )
                ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
                ->selectRaw(
                    "products.id as product_id,
                     product_sizes.width,
                     product_sizes.length,
                     COALESCE(SUM(order_items.quantity), 0) as quantity"
                )
                ->groupBy('products.id', 'product_sizes.width', 'product_sizes.length')
                ->orderByRaw('SUM(order_items.quantity) DESC')
                ->get()
                ->groupBy(fn ($r) => (string) $r->product_id);

            return $productRows->map(function ($r) use ($total, $colorsByProduct, $sizesByProduct): array {
                $qty = (int) $r->total_quantity;
                $pid = (string) $r->id;

                $colors = ($colorsByProduct[$pid] ?? collect())->map(function ($c) use ($qty): array {
                    $cQty = (int) $c->quantity;
                    return [
                        'name'       => $c->color_name,
                        'image_url'  => $c->image ? Storage::disk('public')->url($c->image) : null,
                        'quantity'   => $cQty,
                        'percentage' => $qty > 0 ? round(($cQty / $qty) * 100, 1) : 0.0,
                    ];
                })->values()->all();

                $sizes = ($sizesByProduct[$pid] ?? collect())->map(function ($s) use ($qty): array {
                    $sQty  = (int) $s->quantity;
                    $label = ($s->width && $s->length) ? "{$s->width}x{$s->length}" : "O'lchamsiz";
                    return [
                        'label'      => $label,
                        'width'      => $s->width,
                        'length'     => $s->length,
                        'quantity'   => $sQty,
                        'percentage' => $qty > 0 ? round(($sQty / $qty) * 100, 1) : 0.0,
                    ];
                })->values()->all();

                return [
                    'id'             => $r->id,
                    'name'           => $r->name,
                    'type_name'      => $r->type_name,
                    'quality_name'   => $r->quality_name,
                    'orders_count'   => (int) $r->orders_count,
                    'total_quantity' => $qty,
                    'percentage'     => $total > 0 ? round(($qty / $total) * 100, 1) : 0.0,
                    'colors'         => $colors,
                    'sizes'          => $sizes,
                ];
            })->all();
        });
    }

    // ─── Private helpers ─────────────────────────────────────────────────────

    /**
     * Base query builder: order_items for non-canceled orders in the period.
     * Joins: order_items → orders → product_variants → product_colors → products
     */
    private function baseQuery(string $from, string $to)
    {
        return DB::table('order_items')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('product_variants', 'product_variants.id', '=', 'order_items.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->where('orders.status', '!=', Order::STATUS_CANCELED)
            ->whereBetween(DB::raw('DATE(orders.order_date)'), [$from, $to])
            ->whereNull('products.deleted_at');
    }

    private function querySummary(string $from, string $to): array
    {
        $row = $this->baseQuery($from, $to)
            ->selectRaw('COUNT(DISTINCT orders.id) as total_orders, COALESCE(SUM(order_items.quantity), 0) as total_items')
            ->first();

        return [
            'total_orders' => (int) ($row->total_orders ?? 0),
            'total_items'  => (int) ($row->total_items  ?? 0),
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
                "DATE_FORMAT(orders.order_date, '{$dateFormat}') as period_label,
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity"
            )
            ->groupByRaw("DATE_FORMAT(orders.order_date, '{$dateFormat}')")
            ->orderByRaw("DATE_FORMAT(orders.order_date, '{$dateFormat}')")
            ->get();

        return $rows->map(fn ($r) => [
            'label'          => $r->period_label,
            'orders_count'   => (int) $r->orders_count,
            'total_quantity' => (int) $r->total_quantity,
        ])->all();
    }

    private function queryByType(string $from, string $to): array
    {
        $total = $this->totalItems($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->selectRaw(
                'product_types.id,
                 COALESCE(product_types.type, ?) as name,
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('product_types.id', 'product_types.type')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryByColor(string $from, string $to): array
    {
        $total = $this->totalItems($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->selectRaw(
                'colors.id,
                 COALESCE(colors.name, ?) as name,
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('colors.id', 'colors.name')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryBySize(string $from, string $to): array
    {
        $total = $this->totalItems($from, $to);

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
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity',
                ['O\'lchamsiz']
            )
            ->groupBy('product_sizes.id', 'product_sizes.width', 'product_sizes.length')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryByQuality(string $from, string $to): array
    {
        $total = $this->totalItems($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->selectRaw(
                'product_qualities.id,
                 COALESCE(product_qualities.quality_name, ?) as name,
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('product_qualities.id', 'product_qualities.quality_name')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    private function queryTopProducts(string $from, string $to): array
    {
        $total = $this->totalItems($from, $to);

        // ── Step 1: all products ordered by sales quantity ───────────────────
        $productRows = $this->baseQuery($from, $to)
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->leftJoin('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->selectRaw(
                "products.id,
                 products.name,
                 COALESCE(product_types.type, 'Noma\'lum') as type_name,
                 COALESCE(product_qualities.quality_name, 'Noma\'lum') as quality_name,
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity"
            )
            ->groupBy('products.id', 'products.name', 'product_types.type', 'product_qualities.quality_name')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get();

        if ($productRows->isEmpty()) {
            return [];
        }

        $productIds = $productRows->pluck('id')->filter()->toArray();

        // ── Step 2: color breakdown for all products (single query) ──────────
        $colorsByProduct = $this->baseQuery($from, $to)
            ->whereIn('products.id', $productIds)
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->selectRaw(
                "products.id as product_id,
                 COALESCE(colors.name, 'Noma\'lum') as color_name,
                 product_colors.image as image,
                 COALESCE(SUM(order_items.quantity), 0) as quantity"
            )
            ->groupBy('products.id', 'colors.name', 'product_colors.image')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get()
            ->groupBy(fn ($r) => (string) $r->product_id);

        // ── Step 3: size breakdown for all products (single query) ───────────
        $sizesByProduct = $this->baseQuery($from, $to)
            ->whereIn('products.id', $productIds)
            ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
            ->selectRaw(
                "products.id as product_id,
                 product_sizes.width,
                 product_sizes.length,
                 COALESCE(SUM(order_items.quantity), 0) as quantity"
            )
            ->groupBy('products.id', 'product_sizes.width', 'product_sizes.length')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get()
            ->groupBy(fn ($r) => (string) $r->product_id);

        // ── Merge ────────────────────────────────────────────────────────────
        return $productRows->map(function ($r) use ($total, $colorsByProduct, $sizesByProduct): array {
            $qty = (int) $r->total_quantity;
            $pid = (string) $r->id;

            $colors = ($colorsByProduct[$pid] ?? collect())->map(function ($c) use ($qty): array {
                $cQty = (int) $c->quantity;
                return [
                    'name'       => $c->color_name,
                    'image_url'  => $c->image ? Storage::disk('public')->url($c->image) : null,
                    'quantity'   => $cQty,
                    'percentage' => $qty > 0 ? round(($cQty / $qty) * 100, 1) : 0.0,
                ];
            })->values()->all();

            $sizes = ($sizesByProduct[$pid] ?? collect())->map(function ($s) use ($qty): array {
                $sQty  = (int) $s->quantity;
                $label = ($s->width && $s->length)
                    ? "{$s->width}x{$s->length}"
                    : "O'lchamsiz";
                return [
                    'label'      => $label,
                    'width'      => $s->width,
                    'length'     => $s->length,
                    'quantity'   => $sQty,
                    'percentage' => $qty > 0 ? round(($sQty / $qty) * 100, 1) : 0.0,
                ];
            })->values()->all();

            return [
                'id'             => $r->id,
                'name'           => $r->name,
                'type_name'      => $r->type_name,
                'quality_name'   => $r->quality_name,
                'orders_count'   => (int) $r->orders_count,
                'total_quantity' => $qty,
                'percentage'     => $total > 0 ? round(($qty / $total) * 100, 1) : 0.0,
                'colors'         => $colors,
                'sizes'          => $sizes,
            ];
        })->all();
    }

    private function queryByEdge(string $from, string $to): array
    {
        $total = $this->totalItems($from, $to);

        $rows = $this->baseQuery($from, $to)
            ->leftJoin('product_edges', 'product_edges.id', '=', 'product_variants.product_edge_id')
            ->selectRaw(
                'product_edges.id,
                 COALESCE(product_edges.title, ?) as name,
                 COUNT(DISTINCT orders.id) as orders_count,
                 COALESCE(SUM(order_items.quantity), 0) as total_quantity',
                ['Noma\'lum']
            )
            ->groupBy('product_edges.id', 'product_edges.title')
            ->orderByRaw('SUM(order_items.quantity) DESC')
            ->get();

        return $this->appendPercentage($rows, $total);
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    private function filteredTotal(
        string $from, string $to,
        ?int $typeId, ?int $qualityId, ?int $colorId, ?int $sizeId, ?int $edgeId,
    ): int {
        $query = $this->applyFilters(
            $this->baseQuery($from, $to)->selectRaw('COALESCE(SUM(order_items.quantity), 0) as total'),
            $typeId, $qualityId, $colorId, $sizeId, $edgeId,
        );

        return (int) $query->value('total');
    }

    /**
     * Apply the top-products attribute filters to a query builder. Extracted so
     * the main query and both breakdown queries can never drift apart again —
     * see instructions/phase-0/10.
     */
    private function applyFilters($query, ?int $typeId, ?int $qualityId, ?int $colorId, ?int $sizeId, ?int $edgeId)
    {
        if ($typeId !== null)    $query->where('products.product_type_id', $typeId);
        if ($qualityId !== null) $query->where('products.product_quality_id', $qualityId);
        if ($colorId !== null)   $query->where('product_colors.color_id', $colorId);
        if ($sizeId !== null)    $query->where('product_variants.product_size_id', $sizeId);
        if ($edgeId !== null)    $query->where('product_variants.product_edge_id', $edgeId);

        return $query;
    }

    private function totalItems(string $from, string $to): int
    {
        return (int) $this->baseQuery($from, $to)
            ->selectRaw('COALESCE(SUM(order_items.quantity), 0) as total')
            ->value('total');
    }

    private function appendPercentage($rows, int $total): array
    {
        return $rows->map(function ($row) use ($total): array {
            $qty = (int) $row->total_quantity;
            return [
                'id'             => $row->id,
                'name'           => $row->name,
                'orders_count'   => (int) $row->orders_count,
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
        $toDate  = Carbon::parse($to)->startOfDay();
        $today   = Carbon::today();

        return $toDate->gte($today) ? 300 : 3600;
    }
}
