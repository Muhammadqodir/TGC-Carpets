# 04 — Repoint analytics at `occurred_at` (CALC-1)

Analytics currently dates production by `production_batch_items.updated_at` — a "last touched" stamp. Sum `production_events.quantity` by `occurred_at` instead.

**Severity:** Critical — the owner's production reports are wrong today / **Effort:** 2 days / **Safe on live:** Yes to build, **No to switch silently** — the numbers change, and the owner must see the delta first

## Why this matters

This is the headline fix of phase 2. The production report is wrong, it has always been wrong, and it is wrong in a way that makes it look plausible.

`ProductionAnalyticsService::baseQuery()` filters the period like this (line 58):

```php
->whereBetween(DB::raw('DATE(production_batch_items.updated_at)'), [$from, $to])
```

and the trend groups by it (lines 89, 94, 95):

```php
"DATE_FORMAT(production_batch_items.updated_at, '{$dateFormat}') as period_label"
```

Then it sums `production_batch_items.produced_quantity` (line 67, 91) — a **cumulative lifetime total** — and attributes the whole thing to that one date.

Two independent bugs compound here:

**1. `updated_at` is not a production date.** It means "this row was last written to, for any reason". These all overwrite it (Eloquent's `increment`/`decrement`/`update` touch timestamps by default):

| Writer | Line | What it actually did |
|---|---|---|
| `ProductionBatchService::incrementProducedQuantity` | 167 | printed a label — *the only one that is production* |
| `WarehouseDocumentService::creditProductionBatchItems` | 283 | `increment('warehouse_received_quantity')` — warehouse received goods |
| `WarehouseDocumentService::debitProductionBatchItems` | 309 | `decrement('warehouse_received_quantity')` — a document was reversed |
| `DefectDocumentController::store` | 56–57 | `increment('defect_quantity')` — a defect was logged |
| `ProductionBatchService::updateItem` | 201 | `$item->update([...])` — someone edited a note |

**2. `produced_quantity` is cumulative, not a delta.** So the sum attributes an item's *entire lifetime output* to whatever date last touched the row.

Worked example — 500 carpets, woven 5–7 January:

| Date | What happens | Report says |
|---|---|---|
| Jan 5–7 | 500 labels printed, `updated_at` walks Jan 5 → Jan 7 | Jan 7: 500 (Jan 5, Jan 6: **0**) |
| Jan 20 | warehouse receives them → line 283 fires → `updated_at` = Jan 20 | Jan 7: **0**. Jan 20: **500** |
| Jul 3 | one defect logged → line 56 fires → `updated_at` = Jul 3 | Jan: **0**. Jul 3: **500** |

500 carpets woven in January are reported as July production. January now reports zero. Nobody wove anything in July. **The report moves output between months in response to warehouse and defect activity that has nothing to do with when the carpets were made.**

And because `updated_at` only ever moves forward, output migrates *forward in time*, always. The past silently empties out. A month that looked right in February looks empty in July. If the owner has ever said "January looks low, I thought we did more" — he was right, and this is why.

There is a third, quieter bug: the week format at line 82 is `'%Y-%u'`. `%Y` is the calendar year and `%u` is the ISO-ish week number, and mixing the two is wrong at year boundaries — 2027-01-01 is a Friday in ISO week 53 of 2026, so it labels as `2027-53`, a week that does not exist, sorting after `2027-52`. Fix it to `'%x-%v'` (`%x` = week-based year, `%v` = week of year, same numbering system). This is a real bug but a small one; fix it while you are in here.

## Files to change

| File | Line | What is there now |
|---|---|---|
| `tgc_backend/app/Services/ProductionAnalyticsService.php` | 48–60 | `baseQuery()` — joins + the `updated_at` filter at line 58 |
| ″ | 62–77 | `querySummary()` |
| ″ | 79–104 | `queryTrend()` — `'%Y-%u'` at line 82; `DATE_FORMAT(...updated_at...)` at 89, 94, 95 |
| ″ | 106–214 | `queryByType` / `ByColor` / `BySize` / `ByQuality` / `ByEdge` |
| ″ | 13 | `SQM_EXPR` — multiplies `produced_quantity` by size |
| ″ | 240–249 | `resolveTtl()` |

## The change

### 1. Base the query on events, not on the item row

The join set stays. Add `production_events` and drive both the period filter and the quantity from it:

```php
private function baseQuery(string $from, string $to)
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
```

Then every `SUM(production_batch_items.produced_quantity)` becomes `SUM(production_events.quantity)`, and `SQM_EXPR` (line 13) becomes:

```php
private const SQM_EXPR = 'COALESCE(SUM(production_events.quantity * product_sizes.width * product_sizes.length), 0) / 10000';
```

Changes worth calling out explicitly:

- **`->where('produced_quantity', '>', 0)` (line 57) is deleted.** It was a proxy for "did this item produce anything". Event rows only exist when something happened, so the filter is redundant — and keeping it would wrongly exclude an item that was fully scrapped back to zero.
- **`whereIn(event_type, ['produced','scrap','correction'])`** matches the produced-cache mapping defined in step 01. Do not include `defect` — that feeds a different counter and would inflate output.
- **Signed quantities work correctly for free.** A scrap of −1 subtracts from the day it was scrapped. That is right: production reporting should reflect that the unit was condemned.
- `COUNT(DISTINCT production_batches.id)` still works unchanged.
- Grouping by `production_batch_items.id` is gone entirely — one item now contributes to *many* days, which is exactly the fix.

### 2. Trend: group by `occurred_at`, and fix the week format

```php
$dateFormat = match ($trendBy) {
    'week'  => '%x-%v',      // was '%Y-%u' — wrong at year boundaries
    'month' => '%Y-%m',
    default => '%Y-%m-%d',
};
```

and lines 89 / 94 / 95 all move from `production_batch_items.updated_at` to `production_events.occurred_at`.

### 3. The cache TTL is only now honest

`resolveTtl()` (line 243) returns 3600s for historical ranges, on the stated reasoning that *"historical data won't change"*:

```php
return $toDate->gte($today) ? 300 : 3600;
```

That comment is currently **false**. Under `updated_at`, a July defect entry retroactively rewrites January's numbers — history changes constantly, and the 60-minute cache has been serving numbers that were already stale. Nobody noticed because the underlying numbers were wrong anyway.

After this change the assumption becomes true: `occurred_at` is written once at insert and never updated (step 01), events are append-only, so a closed historical range genuinely cannot change. **Leave `resolveTtl` as it is** — but understand that you are not preserving a working behaviour, you are finally satisfying a precondition that was silently violated. Worth saying out loud to whoever reviews this.

One caveat: a backdated defect (`store()` accepts a client-supplied `datetime`, line 45) or a correction event *can* land in a closed period. That is rare and the cache is only 60 minutes. Accept it; do not build invalidation for it.

**Flush the cache on deploy** — `php artisan cache:clear`, or the owner sees old-formula numbers for up to an hour and you will spend the afternoon explaining a discrepancy that does not exist.

## Rollout: do not just switch it

**The historical numbers will change, and they will change a lot.** January will go from 0 back to 500. July will drop. This is correct — but if the owner opens the report and finds last quarter's output has moved, having not been warned, you have burned the credibility of every number in the system. Do not do that.

Run both versions side by side for **a week**:

1. Extract the current implementation into a private `baseQueryLegacy()` / `queryTrendLegacy()` — keep it byte-identical, do not "tidy it up".
2. Build the new event-based path alongside it.
3. Gate on a config flag, defaulting to legacy:
   ```php
   // config/analytics.php
   'source' => env('ANALYTICS_SOURCE', 'legacy'),   // 'legacy' | 'events'
   ```
   `getReport()` picks the path, **and puts the flag in the cache key** — otherwise you serve legacy numbers from cache after flipping:
   ```php
   $cacheKey = "analytics:production:{$source}:{$from}:{$to}:{$trendBy}";
   ```
4. Add a temporary admin-only route, e.g. `GET /api/v1/analytics/production/compare?from=&to=&trend_by=`, returning both results and the per-period delta. Do not expose it to normal roles; `routes/api.php` already has the `role:` middleware alias registered in `bootstrap/app.php`.
5. **Take the deltas to the owner.** Show him a month where the two disagree and explain, in his terms, why the new number is the true one: *"the report was dating your carpets by the last time anything touched the record — a warehouse receipt, a defect entry. Your January work was being reported as July."* Let him confirm against something he trusts — machine logs, his own recollection of a big month.
6. Only after he has seen it and agrees: set `ANALYTICS_SOURCE=events`, `php artisan config:clear && php artisan cache:clear`.
7. Leave the legacy path in place for one more release, then delete it and the compare route. Do not leave it forever — a dead code path that computes wrong numbers is a trap for whoever comes next.

Expect the compare to show pre-backfill periods dominated by lumps on batch completion dates (step 03). That is the approximation, not a bug. Say so when showing it, and be clear which side of the step-01 deploy date is measured and which is inferred.

## How to verify

No test suite. Manual, on staging with a copy of production data.

1. **Prove the ledger is sound first** — re-run the reconcile query from step 03 (verification #5). If it returns any rows, stop. Repointing reports at a ledger you know is wrong is worse than leaving them broken.
2. **Reproduce the bug, then watch it disappear.** This is the most convincing check available:
   - Find an item with `produced_quantity > 0` whose batch completed months ago.
   - Note today's report for that item's real production month:
     ```bash
     curl "https://<host>/api/v1/analytics/production?from=2026-01-01&to=2026-01-31" \
       -H "Authorization: Bearer <TOKEN>"
     ```
   - Log a defect against that item today (from the app), or just touch it:
     ```sql
     UPDATE production_batch_items SET updated_at = NOW() WHERE id = <ITEM>;   -- staging only!
     ```
   - `php artisan cache:clear`, re-request January. **Legacy: the number drops.** Then flip to `events` and request again — **the number does not move.** That is the fix, demonstrated.
3. **Totals over all time must be preserved.** Across a range wide enough to cover everything, `total_produced` should match between legacy and events, give or take items excluded by the legacy `produced_quantity > 0` filter and any cancelled-batch edge cases. A large unexplained gap means the join is dropping or duplicating rows — most likely the `product_sizes` left join fanning out. Check with:
   ```sql
   SELECT SUM(quantity) FROM production_events e
   JOIN production_batch_items i ON i.id = e.production_batch_item_id
   JOIN production_batches b ON b.id = i.production_batch_id
   WHERE b.status != 'cancelled' AND e.event_type IN ('produced','scrap','correction');
   ```
   against the API's `total_produced` for an all-time range.
4. **Distribution sanity.** Request `trend_by=day` for a recent month. Post-deploy days should show plausible daily output — not one giant spike. Under legacy you will see spikes on warehouse-receipt days. Show the owner both charts; the shape difference is more persuasive than any number.
5. **Week boundary.** Request `from=2026-12-28&to=2027-01-04&trend_by=week`. Labels must be `%x-%v` values that increment sanely across the year boundary (`2026-53` → `2027-01`), with no `2027-53`.
6. **Every breakdown must still total.** For `by_type`, `by_color`, `by_size`, `by_quality`, `by_edge` — each one's `total_quantity` summed across rows must equal `summary.total_produced`, and `percentage` must sum to ~100. If a breakdown disagrees, its extra `leftJoin` is fanning rows out.
7. **Performance.** `production_events` is much larger than `production_batch_items`. Time a 1-year `trend_by=day` request and `EXPLAIN` it — confirm it uses `idx_time` on `occurred_at`. If it table-scans, the `DATE(occurred_at)` wrapper is the likely culprit; rewrite as `occurred_at >= ? AND occurred_at < DATE_ADD(?, INTERVAL 1 DAY)` so the index is usable.

## Rollback

Genuinely easy, which is the reason for the flag:

- **Instant:** `ANALYTICS_SOURCE=legacy`, then `php artisan config:clear && php artisan cache:clear`. No deploy, no migration. Numbers return to their old (wrong, familiar) values within seconds.
- **Full:** revert the service. `production_events` is untouched by this step — it is read-only here — so there is nothing to undo in the data.
- The `'%x-%v'` fix travels with the revert. If you want to keep it while rolling back the rest, it is an independent one-line change to line 82.
- **Do not roll back by deleting events.** If the numbers look wrong, the ledger is the evidence you need to work out why.

## Depends on / blocks

- **Depends on: 01** (the table and dual-write must be live and correct) **and 03** (without the backfill this reports zero production before the step-01 deploy date — the owner's entire history disappears).
- **Strongly prefer after 02.** Every double-counted label from a retried print is permanent noise in these numbers. Better that the owner's first look at event-sourced analytics is not polluted by known double-counts.
- **Blocks:** nothing. This is the payoff step — the one the owner will actually see.
- 06 (reconcile) is independent but should be scheduled **before** you flip the flag, so that if cache and log ever drift you find out from an alert rather than from the owner asking why the report changed.
