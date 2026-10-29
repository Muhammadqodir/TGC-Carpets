<?php

namespace App\Services;

use App\Models\ProductionBatch;
use App\Models\ProductionEvent;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * Shop-floor view of production: who made it (shift), where (machine),
 * when (hour of day), and how close each one runs to its own capacity.
 *
 * Always reads production_events, whatever config('analytics.source')
 * says. A shift is the account that printed the label (events.user_id),
 * and only the event log knows that; the legacy counters cannot be split
 * by person or hour at all.
 *
 * Rules every query here shares:
 *  - reason='backfill' events are left out. Each one is a single lump for
 *    a whole pre-2026-07 batch line, dated to batch completion and put on
 *    the batch creator. It would show up as a fake record day, a fake
 *    hour and a fake "shift". summary.backfilled_excluded says how many
 *    carpets that left out of the period.
 *  - Days are production days. A day starts at
 *    config('analytics.production_day_start_hour') local time, so a night
 *    shift that runs past midnight counts as one working day instead of
 *    two half days. The period filter uses the same day.
 *  - Capacity is the best production day observed in the period, per
 *    shift or machine (the owner's choice: there is no configured norm).
 *    Utilisation = average working day ÷ best day.
 */
class ProductionOperationsAnalyticsService
{
    public function getReport(string $from, string $to, string $trendBy = 'day'): array
    {
        $dayStart = $this->dayStartHour();
        $cacheKey = "analytics:production-ops:{$from}:{$to}:{$trendBy}:{$dayStart}";

        return Cache::remember($cacheKey, $this->resolveTtl($to), fn (): array => [
            'day_start_hour' => $dayStart,
            'summary'        => $this->summary($from, $to),
            'trend'          => $this->trend($from, $to, $trendBy),
            'by_shift'       => $this->byShift($from, $to),
            'by_machine'     => $this->byMachine($from, $to),
            'heatmap'        => $this->heatmap($from, $to),
        ]);
    }

    // ─── Sections ────────────────────────────────────────────────────────────

    private function summary(string $from, string $to): array
    {
        $days     = $this->dailyRows($this->outputQuery($from, $to), null);
        $stats    = $this->capacityStats($days->get('', collect()));
        $defects  = (int) $this->defectQuery($from, $to)->sum('e.quantity');
        $reprints = $this->reprintQuery($from, $to)
            ->selectRaw('lr.reason, COUNT(*) as total')
            ->groupBy('lr.reason')
            ->pluck('total', 'reason');

        $backfilled = (int) $this->eventsQuery($from, $to, includeBackfill: true)
            ->whereIn('e.event_type', ProductionEvent::PRODUCED_TYPES)
            ->where('e.reason', 'backfill')
            ->sum('e.quantity');

        return [
            ...$stats,
            'period_days'         => Carbon::parse($from)->diffInDays(Carbon::parse($to)) + 1,
            'total_defects'       => $defects,
            'defect_rate'         => $this->defectRate($stats['total_quantity'], $defects),
            'reprints'            => (int) ($reprints['reprint'] ?? 0),
            'over_target_prints'  => (int) ($reprints['over_target'] ?? 0),
            'backfilled_excluded' => $backfilled,
        ];
    }

    /**
     * One row per account that printed labels. Counts 'produced' events
     * only: scrap/correction events are bookkeeping by whoever fixed the
     * line (often an admin), not output of a shift, and would show that
     * person as a shift with negative production.
     *
     * Defects are put on the account that recorded the defect document,
     * which is the only person a defect event knows. If someone other
     * than the shift accounts records defects, they get a row of their own
     * with defects and no output, rather than being guessed onto a shift.
     */
    private function byShift(string $from, string $to): array
    {
        $daily = $this->dailyRows(
            $this->eventsQuery($from, $to)->where('e.event_type', ProductionEvent::TYPE_PRODUCED),
            'e.user_id',
        );

        $defects = $this->defectQuery($from, $to)
            ->selectRaw('e.user_id as key_id, SUM(e.quantity) as total')
            ->groupBy('e.user_id')
            ->pluck('total', 'key_id');

        $reprints = $this->reprintCounts($from, $to, 'lr.printed_by');

        $ids   = $daily->keys()->merge($defects->keys())->merge(array_keys($reprints))->unique()->values();
        $names = DB::table('users')->whereIn('id', $ids)->pluck('name', 'id');

        return $this->assembleRows($ids, $names, $daily, $defects, $reprints);
    }

    /** Every machine, including ones with no output in the period: an idle loom is the finding. */
    private function byMachine(string $from, string $to): array
    {
        $daily = $this->dailyRows($this->outputQuery($from, $to), 'b.machine_id');

        $defects = $this->defectQuery($from, $to)
            ->selectRaw('b.machine_id as key_id, SUM(e.quantity) as total')
            ->groupBy('b.machine_id')
            ->pluck('total', 'key_id');

        $reprints = $this->reprintCounts($from, $to, 'b.machine_id');

        $names = DB::table('machines')->orderBy('name')->pluck('name', 'id');
        $ids   = $names->keys()->merge($daily->keys())->merge($defects->keys())->merge(array_keys($reprints))
            ->unique()->values();

        return $this->assembleRows($ids, $names, $daily, $defects, $reprints);
    }

    /**
     * Output per period bucket per account that printed — the per-shift
     * bars of the trend chart. 'produced' events only, like byShift(), so
     * the bars add up to the shift totals. Buckets are production days
     * (or ISO weeks / months of them).
     */
    private function trend(string $from, string $to, string $trendBy): array
    {
        $format = match ($trendBy) {
            'week'  => '%x-%v',
            'month' => '%Y-%m',
            default => '%Y-%m-%d',
        };
        $bucket = "DATE_FORMAT(DATE_SUB(e.occurred_at, INTERVAL {$this->dayStartHour()} HOUR), '{$format}')";

        return $this->eventsQuery($from, $to)
            ->where('e.event_type', ProductionEvent::TYPE_PRODUCED)
            ->selectRaw(
                "{$bucket} as label, e.user_id, "
                . 'SUM(e.quantity) as total_quantity, ' . $this->sqmSum() . ' as total_sqm'
            )
            ->groupByRaw("{$bucket}, e.user_id")
            ->orderByRaw("{$bucket}, e.user_id")
            ->get()
            ->map(fn ($r) => [
                'label'          => $r->label,
                'user_id'        => (int) $r->user_id,
                'total_quantity' => (int) $r->total_quantity,
                'total_sqm'      => round((float) $r->total_sqm, 2),
            ])
            ->all();
    }

    /**
     * Labels printed per weekday (0 = Monday) × clock hour, per account.
     * Uses the real clock, not the production day, so a 02:00 print sits
     * in the 02 column of the weekday it happened on.
     */
    private function heatmap(string $from, string $to): array
    {
        return $this->eventsQuery($from, $to)
            ->where('e.event_type', ProductionEvent::TYPE_PRODUCED)
            ->selectRaw(
                'e.user_id, WEEKDAY(e.occurred_at) as weekday, HOUR(e.occurred_at) as hour, '
                . 'SUM(e.quantity) as total_quantity, ' . $this->sqmSum() . ' as total_sqm'
            )
            ->groupByRaw('e.user_id, WEEKDAY(e.occurred_at), HOUR(e.occurred_at)')
            ->orderByRaw('weekday, hour')
            ->get()
            ->map(fn ($r) => [
                'user_id'        => (int) $r->user_id,
                'weekday'        => (int) $r->weekday,
                'hour'           => (int) $r->hour,
                'total_quantity' => (int) $r->total_quantity,
                'total_sqm'      => round((float) $r->total_sqm, 2),
            ])
            ->all();
    }

    // ─── Query builders ──────────────────────────────────────────────────────

    private function eventsQuery(string $from, string $to, bool $includeBackfill = false)
    {
        $query = DB::table('production_events as e')
            ->join('production_batch_items as i', 'i.id', '=', 'e.production_batch_item_id')
            ->join('production_batches as b', 'b.id', '=', 'i.production_batch_id')
            ->join('product_variants as v', 'v.id', '=', 'i.product_variant_id')
            ->join('product_colors as pc', 'pc.id', '=', 'v.product_color_id')
            ->join('products as p', 'p.id', '=', 'pc.product_id')
            ->leftJoin('product_sizes as s', 's.id', '=', 'v.product_size_id')
            ->where('b.status', '!=', ProductionBatch::STATUS_CANCELLED)
            ->whereNull('p.deleted_at')
            ->whereBetween(DB::raw($this->productionDay('e.occurred_at')), [$from, $to]);

        if (! $includeBackfill) {
            $query->where(fn ($q) => $q->whereNull('e.reason')->orWhere('e.reason', '!=', 'backfill'));
        }

        return $query;
    }

    /** Net output, the same event types that make up produced_quantity. */
    private function outputQuery(string $from, string $to)
    {
        return $this->eventsQuery($from, $to)->whereIn('e.event_type', ProductionEvent::PRODUCED_TYPES);
    }

    private function defectQuery(string $from, string $to)
    {
        return $this->eventsQuery($from, $to)->where('e.event_type', ProductionEvent::TYPE_DEFECT);
    }

    private function reprintQuery(string $from, string $to)
    {
        return DB::table('label_reprints as lr')
            ->join('production_batch_items as i', 'i.id', '=', 'lr.production_batch_item_id')
            ->join('production_batches as b', 'b.id', '=', 'i.production_batch_id')
            ->whereBetween(DB::raw($this->productionDay('lr.printed_at')), [$from, $to]);
    }

    /** [key => ['reprint' => n, 'over_target' => n]] */
    private function reprintCounts(string $from, string $to, string $keyExpr): array
    {
        $out = [];
        $rows = $this->reprintQuery($from, $to)
            ->selectRaw("{$keyExpr} as key_id, lr.reason, COUNT(*) as total")
            ->groupByRaw("{$keyExpr}, lr.reason")
            ->get();

        foreach ($rows as $r) {
            $out[$r->key_id][$r->reason] = (int) $r->total;
        }

        return $out;
    }

    /**
     * Output per (key, production day), grouped by key. With $keyExpr null
     * everything lands under the key ''.
     *
     * @return Collection<string|int, Collection<int, object>>
     */
    private function dailyRows($query, ?string $keyExpr): Collection
    {
        $day = $this->productionDay('e.occurred_at');
        $key = $keyExpr ?? "''";

        return $query
            ->selectRaw(
                "{$key} as key_id, {$day} as day, "
                . 'SUM(e.quantity) as total_quantity, ' . $this->sqmSum() . ' as total_sqm'
            )
            ->groupByRaw("{$key}, {$day}")
            ->get()
            ->groupBy('key_id');
    }

    // ─── Assembly ────────────────────────────────────────────────────────────

    private function assembleRows(Collection $ids, Collection $names, Collection $daily, Collection $defects, array $reprints): array
    {
        return $ids
            ->map(function ($id) use ($names, $daily, $defects, $reprints): array {
                $stats   = $this->capacityStats($daily->get($id, collect()));
                $defectN = (int) ($defects[$id] ?? 0);

                return [
                    'id'                 => ($id === null || $id === '') ? null : (int) $id,
                    'name'               => $names[$id] ?? 'Noma\'lum',
                    ...$stats,
                    'total_defects'      => $defectN,
                    'defect_rate'        => $this->defectRate($stats['total_quantity'], $defectN),
                    'reprints'           => (int) ($reprints[$id]['reprint'] ?? 0),
                    'over_target_prints' => (int) ($reprints[$id]['over_target'] ?? 0),
                ];
            })
            ->sortByDesc('total_quantity')
            ->values()
            ->all();
    }

    /**
     * Totals, average working day and best day for one set of daily rows,
     * separately for pieces and m²: the best day by count is often not the
     * best day by area.
     */
    private function capacityStats(Collection $days): array
    {
        $working = $days->filter(fn ($d) => (int) $d->total_quantity > 0);
        $n       = $working->count();
        $qty     = (int) $days->sum('total_quantity');
        $sqm     = round((float) $days->sum('total_sqm'), 2);

        $bestQty = $working->sortByDesc(fn ($d) => (int) $d->total_quantity)->first();
        $bestSqm = $working->sortByDesc(fn ($d) => (float) $d->total_sqm)->first();

        $avgQty = $n > 0 ? round($qty / $n, 1) : 0.0;
        $avgSqm = $n > 0 ? round($sqm / $n, 2) : 0.0;

        $bestQtyVal = $bestQty ? (int) $bestQty->total_quantity : 0;
        $bestSqmVal = $bestSqm ? round((float) $bestSqm->total_sqm, 2) : 0.0;

        return [
            'total_quantity'          => $qty,
            'total_sqm'               => $sqm,
            'working_days'            => $n,
            'avg_quantity_per_day'    => $avgQty,
            'avg_sqm_per_day'         => $avgSqm,
            'best_day_quantity'       => $bestQtyVal,
            'best_day_quantity_date'  => $bestQty?->day,
            'best_day_sqm'            => $bestSqmVal,
            'best_day_sqm_date'       => $bestSqm?->day,
            'utilization_quantity'    => $bestQtyVal > 0 ? round($avgQty / $bestQtyVal * 100, 1) : null,
            'utilization_sqm'         => $bestSqmVal > 0 ? round($avgSqm / $bestSqmVal * 100, 1) : null,
        ];
    }

    // ─── Utilities ───────────────────────────────────────────────────────────

    private function dayStartHour(): int
    {
        return max(0, min(23, (int) config('analytics.production_day_start_hour', 7)));
    }

    /** SQL for the production day a timestamp column belongs to. */
    private function productionDay(string $column): string
    {
        return "DATE(DATE_SUB({$column}, INTERVAL {$this->dayStartHour()} HOUR))";
    }

    private function sqmSum(): string
    {
        return 'COALESCE(SUM(e.quantity * s.width * s.length), 0) / 10000';
    }

    /** Same definition as ProductionAnalyticsService: defects as a share of everything made. */
    private function defectRate(int $produced, int $defects): ?float
    {
        $base = $produced + $defects;

        return $base > 0 ? round($defects / $base * 100, 2) : null;
    }

    private function resolveTtl(string $to): int
    {
        return Carbon::parse($to)->startOfDay()->gte(Carbon::today()) ? 300 : 3600;
    }
}
