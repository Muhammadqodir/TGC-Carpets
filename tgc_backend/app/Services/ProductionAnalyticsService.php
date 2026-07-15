<?php

namespace App\Services;

use App\Models\ProductionBatch;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * Production report, readable from two sources — see
 * instructions/phase-2/04-repoint-analytics-to-occurred-at.md (CALC-1).
 *
 *   'legacy' — production_batch_items.updated_at / produced_quantity. Wrong:
 *              updated_at moves on any write (warehouse receipt, defect
 *              entry, a note edit), not just production, and
 *              produced_quantity is a cumulative lifetime total attributed
 *              in full to whichever date last touched the row.
 *   'events' — production_events.occurred_at / SUM(quantity). Correct: an
 *              event is written once, at the moment production happened,
 *              and never mutated.
 *
 * config('analytics.source') selects which one getReport() serves. Both
 * paths are kept side by side (not one replacing the other) so
 * compare() can show the owner the delta before the flag is flipped — do
 * not delete the legacy path until that has happened and one more release
 * has shipped after it. See the instruction file's "Rollout" section.
 */
class ProductionAnalyticsService
{
    /**
     * Full report for produced items in the given date range, from
     * whichever source config('analytics.source') selects.
     *
     * Cached: 5 minutes when the period includes today, 60 minutes for
     * purely historical ranges. The source is part of the cache key so
     * flipping the flag can never serve a stale reading from the other
     * source.
     */
    public function getReport(string $from, string $to, string $trendBy = 'day'): array
    {
        $source = config('analytics.source', 'legacy');

        return $this->buildReport($source, $from, $to, $trendBy);
    }

    /**
     * Admin-only diagnostic: both sources computed side by side, with a
     * per-period delta on the trend. Never cached — this is a one-off
     * comparison, not a report anyone should be hitting repeatedly. See
     * instructions/phase-2/04's "Rollout" step 4-5: show this to the owner
     * before flipping ANALYTICS_SOURCE.
     */
    public function compare(string $from, string $to, string $trendBy = 'day'): array
    {
        $legacy = $this->buildReport('legacy', $from, $to, $trendBy, bypassCache: true);
        $events = $this->buildReport('events', $from, $to, $trendBy, bypassCache: true);

        $legacyByLabel = collect($legacy['trend'])->keyBy('label');
        $eventsByLabel = collect($events['trend'])->keyBy('label');
        $labels = $legacyByLabel->keys()->merge($eventsByLabel->keys())->unique()->sort()->values();

        $trendDelta = $labels->map(function ($label) use ($legacyByLabel, $eventsByLabel): array {
            $legacyQty = (int) ($legacyByLabel->get($label)['total_quantity'] ?? 0);
            $eventsQty = (int) ($eventsByLabel->get($label)['total_quantity'] ?? 0);

            return [
                'label'  => $label,
                'legacy' => $legacyQty,
                'events' => $eventsQty,
                'delta'  => $eventsQty - $legacyQty,
            ];
        })->values()->all();

        return [
            'legacy'      => $legacy,
            'events'      => $events,
            'trend_delta' => $trendDelta,
            'summary_delta' => [
                'legacy_total_produced' => $legacy['summary']['total_produced'],
                'events_total_produced' => $events['summary']['total_produced'],
                'delta'                 => $events['summary']['total_produced'] - $legacy['summary']['total_produced'],
            ],
        ];
    }

    // ─── Report assembly ─────────────────────────────────────────────────────

    private function buildReport(string $source, string $from, string $to, string $trendBy, bool $bypassCache = false): array
    {
        $ttl      = $this->resolveTtl($to);
        $cacheKey = "analytics:production:{$source}:{$from}:{$to}:{$trendBy}";

        $build = function () use ($source, $from, $to, $trendBy): array {
            return [
                'summary'    => $this->querySummary($source, $from, $to),
                'trend'      => $this->queryTrend($source, $from, $to, $trendBy),
                'by_type'    => $this->queryByType($source, $from, $to),
                'by_color'   => $this->queryByColor($source, $from, $to),
                'by_size'    => $this->queryBySize($source, $from, $to),
                'by_quality' => $this->queryByQuality($source, $from, $to),
                'by_edge'    => $this->queryByEdge($source, $from, $to),
            ];
        };

        return $bypassCache ? $build() : Cache::remember($cacheKey, $ttl, $build);
    }

    // ─── Source-aware column helpers ────────────────────────────────────────

    /** The raw quantity column each source sums. */
    private function quantityExpr(string $source): string
    {
        return $source === 'events'
            ? 'production_events.quantity'
            : 'production_batch_items.produced_quantity';
    }

    /** The real business-time column each source dates a period by. */
    private function dateExpr(string $source): string
    {
        return $source === 'events'
            ? 'production_events.occurred_at'
            : 'production_batch_items.updated_at';
    }

    private function qtySumExpr(string $source): string
    {
        return 'COALESCE(SUM(' . $this->quantityExpr($source) . '), 0)';
    }

    private function sqmExpr(string $source): string
    {
        $qty = $this->quantityExpr($source);

        return "COALESCE(SUM({$qty} * product_sizes.width * product_sizes.length), 0) / 10000";
    }

    /**
     * Base query builder, dispatched by source.
     *
     * legacy: only items that have ever produced anything
     * (produced_quantity > 0), for non-cancelled batches, whose counter was
     * last touched within the period.
     *
     * events: 'produced'/'scrap'/'correction' events (the ones that feed
     * produced_quantity — see ProductionEvent's mapping; 'defect' is
     * excluded, it feeds a different counter and would inflate output) for
     * non-cancelled batches, whose occurred_at falls within the period.
     * Signed quantities (a scrap is -n) net out correctly with a plain SUM.
     */
    private function baseQuery(string $source, string $from, string $to)
    {
        return $source === 'events'
            ? $this->baseQueryEvents($from, $to)
            : $this->baseQueryLegacy($from, $to);
    }

    private function baseQueryLegacy(string $from, string $to)
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

    private function baseQueryEvents(string $from, string $to)
    {
        return DB::table('production_events')
            ->join('production_batch_items', 'production_batch_items.id', '=', 'production_events.production_batch_item_id')
            ->join('production_batches', 'production_batches.id', '=', 'production_batch_items.production_batch_id')
            ->join('product_variants', 'product_variants.id', '=', 'production_batch_items.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
            ->where('production_batches.status', '!=', ProductionBatch::STATUS_CANCELLED)
            ->whereIn('production_events.event_type', ['produced', 'scrap', 'correction'])
            ->whereBetween(DB::raw('DATE(production_events.occurred_at)'), [$from, $to])
            ->whereNull('products.deleted_at');
    }

    // ─── Queries ─────────────────────────────────────────────────────────────

    private function querySummary(string $source, string $from, string $to): array
    {
        $row = $this->baseQuery($source, $from, $to)
            ->selectRaw(
                'COUNT(DISTINCT production_batches.id) as total_batches, '
                . $this->qtySumExpr($source) . ' as total_produced, '
                . $this->sqmExpr($source) . ' as total_sqm'
            )
            ->first();

        return [
            'total_batches'  => (int) ($row->total_batches ?? 0),
            'total_produced' => (int) ($row->total_produced ?? 0),
            'total_sqm'      => round((float) ($row->total_sqm ?? 0), 2),
        ];
    }

    private function queryTrend(string $source, string $from, string $to, string $trendBy): array
    {
        // '%x-%v' (week-based year + ISO week), not '%Y-%u' — the latter mixes
        // calendar year with ISO-ish week number and mislabels the boundary
        // (e.g. 2027-01-01 is ISO week 53 of 2026, so '%Y-%u' emits the
        // non-existent '2027-53'). Fixed regardless of source.
        $dateFormat = match ($trendBy) {
            'week'  => '%x-%v',
            'month' => '%Y-%m',
            default => '%Y-%m-%d',
        };

        $dateCol = $this->dateExpr($source);

        $rows = $this->baseQuery($source, $from, $to)
            ->selectRaw(
                "DATE_FORMAT({$dateCol}, '{$dateFormat}') as period_label, "
                . 'COUNT(DISTINCT production_batches.id) as batches_count, '
                . $this->qtySumExpr($source) . ' as total_quantity, '
                . $this->sqmExpr($source) . ' as total_sqm'
            )
            ->groupByRaw("DATE_FORMAT({$dateCol}, '{$dateFormat}')")
            ->orderByRaw("DATE_FORMAT({$dateCol}, '{$dateFormat}')")
            ->get();

        return $rows->map(fn ($r) => [
            'label'          => $r->period_label,
            'batches_count'  => (int) $r->batches_count,
            'total_quantity' => (int) $r->total_quantity,
            'total_sqm'      => round((float) $r->total_sqm, 2),
        ])->all();
    }

    private function queryByType(string $source, string $from, string $to): array
    {
        $totalQty = $this->totalProduced($source, $from, $to);

        $rows = $this->baseQuery($source, $from, $to)
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->selectRaw(
                'product_types.id, COALESCE(product_types.type, ?) as name, '
                . 'COUNT(DISTINCT production_batches.id) as batches_count, '
                . $this->qtySumExpr($source) . ' as total_quantity, '
                . $this->sqmExpr($source) . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('product_types.id', 'product_types.type')
            ->orderByRaw('SUM(' . $this->quantityExpr($source) . ') DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryByColor(string $source, string $from, string $to): array
    {
        $totalQty = $this->totalProduced($source, $from, $to);

        $rows = $this->baseQuery($source, $from, $to)
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->selectRaw(
                'colors.id, COALESCE(colors.name, ?) as name, '
                . 'COUNT(DISTINCT production_batches.id) as batches_count, '
                . $this->qtySumExpr($source) . ' as total_quantity, '
                . $this->sqmExpr($source) . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('colors.id', 'colors.name')
            ->orderByRaw('SUM(' . $this->quantityExpr($source) . ') DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryBySize(string $source, string $from, string $to): array
    {
        $totalQty = $this->totalProduced($source, $from, $to);

        $rows = $this->baseQuery($source, $from, $to)
            ->selectRaw(
                'product_sizes.id,
                 CASE
                     WHEN product_sizes.id IS NOT NULL
                     THEN CONCAT(product_sizes.width, "x", product_sizes.length)
                     ELSE ?
                 END as name,
                 product_sizes.width,
                 product_sizes.length, '
                . 'COUNT(DISTINCT production_batches.id) as batches_count, '
                . $this->qtySumExpr($source) . ' as total_quantity, '
                . $this->sqmExpr($source) . ' as total_sqm',
                ['O\'lchamsiz']
            )
            ->groupBy('product_sizes.id', 'product_sizes.width', 'product_sizes.length')
            ->orderByRaw('SUM(' . $this->quantityExpr($source) . ') DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryByQuality(string $source, string $from, string $to): array
    {
        $totalQty = $this->totalProduced($source, $from, $to);

        $rows = $this->baseQuery($source, $from, $to)
            ->leftJoin('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->selectRaw(
                'product_qualities.id, COALESCE(product_qualities.quality_name, ?) as name, '
                . 'COUNT(DISTINCT production_batches.id) as batches_count, '
                . $this->qtySumExpr($source) . ' as total_quantity, '
                . $this->sqmExpr($source) . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('product_qualities.id', 'product_qualities.quality_name')
            ->orderByRaw('SUM(' . $this->quantityExpr($source) . ') DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    private function queryByEdge(string $source, string $from, string $to): array
    {
        $totalQty = $this->totalProduced($source, $from, $to);

        $rows = $this->baseQuery($source, $from, $to)
            ->leftJoin('product_edges', 'product_edges.id', '=', 'product_variants.product_edge_id')
            ->selectRaw(
                'product_edges.id, COALESCE(product_edges.title, ?) as name, '
                . 'COUNT(DISTINCT production_batches.id) as batches_count, '
                . $this->qtySumExpr($source) . ' as total_quantity, '
                . $this->sqmExpr($source) . ' as total_sqm',
                ['Noma\'lum']
            )
            ->groupBy('product_edges.id', 'product_edges.title')
            ->orderByRaw('SUM(' . $this->quantityExpr($source) . ') DESC')
            ->get();

        return $this->appendPercentage($rows, $totalQty);
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    private function totalProduced(string $source, string $from, string $to): int
    {
        return (int) $this->baseQuery($source, $from, $to)
            ->selectRaw($this->qtySumExpr($source) . ' as total')
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
     * 5 min TTL if the period includes today; 60 min otherwise. Under the
     * 'events' source this is now honest: occurred_at is written once at
     * insert and never updated, events are append-only, so a closed
     * historical range genuinely cannot change (bar a rare backdated defect
     * or correction landing in a closed period — accepted, the cache is
     * short). Under 'legacy' the comment was never true — a later write to
     * production_batch_items retroactively rewrites an already-cached
     * historical period — which is the bug this whole step exists to fix.
     */
    private function resolveTtl(string $to): int
    {
        $toDate = Carbon::parse($to)->startOfDay();
        $today  = Carbon::today();

        return $toDate->gte($today) ? 300 : 3600;
    }
}
