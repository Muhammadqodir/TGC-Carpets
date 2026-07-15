# Fix empty date parameters silently zeroing analytics reports

`input()` only applies its default when the key is **absent**. A cleared date picker sends an empty string, which passes validation and produces zero rows with HTTP 200.

**Severity:** Medium · **Effort:** 30 min · **Safe on live:** Yes

**Finding:** CALC-5 · **Depends on:** nothing

**Status:** ✅ Implemented 2026-07-15 — see [DEPLOY.md](DEPLOY.md) before shipping.

## Why this matters

`app/Http/Requests/Analytics/ProductAnalyticsRequest.php`:

```php
'period_from' => ['nullable', 'date', 'before_or_equal:period_to'],
'period_to'   => ['nullable', 'date', 'after_or_equal:period_from'],

public function periodFrom(): string
{
    return $this->input('period_from', now()->subDays(30)->toDateString());
}
```

Two problems compound:

1. **`['nullable', 'date']` passes an empty string.** `nullable` short-circuits the `date` rule for empty values, so `?period_from=` is valid input.
2. **`input()`'s default only fires when the key is missing.** `?period_from=` means the key is *present* with value `''`, so the default is never applied and `periodFrom()` returns `''`.

The empty string reaches SQL as `DATE(orders.order_date) BETWEEN '' AND '2026-07-14'`. MySQL cannot coerce `''` to a date, matches nothing, and returns **zero rows** — with HTTP 200 and a perfectly well-formed response body full of zeros.

Then `ProductAnalyticsService::getReport()` caches it under `analytics:products::2026-07-14:day` for five minutes, so the user sees the empty report even after fixing their input.

### Failure scenario

The front end clears a date field and sends `?period_from=&period_to=2026-07-14`. Every metric reports **0**. No error, no warning. The user concludes the factory produced nothing, or that the ERP is broken — and they're half right.

## Files to change

Same pattern in all three:

- `app/Http/Requests/Analytics/ProductAnalyticsRequest.php` — `periodFrom()`, `periodTo()`, `trendBy()`
- `app/Http/Requests/Analytics/ProductionAnalyticsRequest.php` — same accessors
- `app/Http/Requests/Analytics/TopProductsFilterRequest.php` — same, plus see the extra fix below

## The change

Use `filled()`, which is false for both absent and empty values:

```php
public function periodFrom(): string
{
    return $this->filled('period_from')
        ? $this->input('period_from')
        : now()->subDays(30)->toDateString();
}

public function periodTo(): string
{
    return $this->filled('period_to')
        ? $this->input('period_to')
        : now()->toDateString();
}

public function trendBy(): string
{
    return $this->filled('trend_by')
        ? $this->input('trend_by')
        : 'day';
}
```

### Better: reject it instead

Silently substituting a default for a malformed request is how this class of bug hides. If the client sends `period_from=`, that is a client bug, and a 422 would have surfaced it years ago. Consider tightening the rules so an empty string is invalid while an absent key still gets the default:

```php
'period_from' => ['sometimes', 'required', 'date', 'before_or_equal:period_to'],
```

`sometimes` + `required` means: if you send the key at all, it must be non-empty.

**Do both.** `filled()` makes the accessors safe regardless; the rules make client bugs visible. But check the Flutter client first — if it currently sends empty strings, tightening the rule returns 422 to users mid-shift:

```bash
grep -rn "period_from\|period_to" tgc_client/lib --include='*.dart'
```

If it does, ship `filled()` now and the rule tightening after the client is fixed.

### `TopProductsFilterRequest` is missing its ordering guard

While you're in the file: `TopProductsFilterRequest` has

```php
'period_from' => ['nullable', 'date'],
'period_to'   => ['nullable', 'date'],
```

with **no** `before_or_equal` / `after_or_equal`, unlike its two siblings. So a reversed range returns an empty array with HTTP 200 instead of a 422. Add them to match.

## Related, not fixed here

`resolveTtl()` grants historical ranges a 60-minute cache on the premise that history doesn't change, and there is **no cache invalidation anywhere** in `app/` (zero `Cache::forget`/`tags`/`flush` calls). That premise is false today because of CALC-1 — see `phase-2/04`. Don't fix caching here; it isn't a caching bug.

## How to verify

```bash
# 1. Empty param — must return the last-30-days default, NOT zeros
curl -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/analytics/products?period_from=&period_to=2026-07-14"

# 2. Absent param — must behave identically to (1)
curl -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/analytics/products?period_to=2026-07-14"

# 3. Normal range — must be unchanged from today's behaviour
curl -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/analytics/products?period_from=2026-06-01&period_to=2026-06-30"
```

1 and 2 must return identical bodies. 3 must be byte-identical to what the endpoint returns before your change.

4. Clear the cache between runs (`php artisan cache:clear`) or you will test the cache, not the code. This is easy to get wrong — the 5-minute TTL is longer than your patience.
5. Repeat all three against `/analytics/production` and `/analytics/top-products`.
6. In the Flutter app, clear a date field and confirm the report shows sensible numbers rather than zeros.

## Rollback

Revert the commit. Nothing is written; this only affects how request parameters are read.
