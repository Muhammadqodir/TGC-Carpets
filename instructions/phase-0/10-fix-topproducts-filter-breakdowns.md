# Reapply filters in the top-products breakdowns — percentages reach 400%

The breakdowns are re-derived from a fresh **unfiltered** query, then divided by the **filtered** total.

**Severity:** Medium · **Effort:** 1 h · **Safe on live:** Yes

**Finding:** CALC-5 · **Depends on:** nothing

**Status:** ✅ Implemented 2026-07-15 — see [DEPLOY.md](DEPLOY.md) before shipping.

## Why this matters

In `app/Services/ProductAnalyticsService.php`, `getFilteredTopProducts()` applies five filters to the main query:

```php
if ($typeId !== null)    $query->where('products.product_type_id', $typeId);
if ($qualityId !== null) $query->where('products.product_quality_id', $qualityId);
if ($colorId !== null)   $query->where('product_colors.color_id', $colorId);
if ($sizeId !== null)    $query->where('product_variants.product_size_id', $sizeId);
if ($edgeId !== null)    $query->where('product_variants.product_edge_id', $edgeId);

$productRows = $query->get();
```

Then the colour and size breakdowns start over from a **fresh `baseQuery()`** with none of those filters:

```php
$colorsByProduct = $this->baseQuery($from, $to)
    ->whereIn('products.id', $productIds)          // ← the ONLY filter carried over
    ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
    ...

$sizesByProduct = $this->baseQuery($from, $to)
    ->whereIn('products.id', $productIds)          // ← same
    ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
    ...
```

And the percentage divides the **unfiltered** breakdown quantity by the **filtered** parent total:

```php
$qty = (int) $r->total_quantity;                   // filtered

$colors = (...)->map(function ($c) use ($qty): array {
    $cQty = (int) $c->quantity;                    // UNfiltered
    return [
        'percentage' => $qty > 0 ? round(($cQty / $qty) * 100, 1) : 0.0,
    ];
});
```

### Failure scenario

Product "Shirvan" sold in the period: **red 100**, **blue 400** (total 500). The user requests `?color_id=<red>`.

| Field | Returns | Should return |
|---|---|---|
| `total_quantity` | 100 ✓ | 100 |
| `colors[]` → red | 100 → **100%** | 100 → 100% |
| `colors[]` → blue | 400 → **400%** | *(absent)* |

The response shows a product whose total is 100 units, containing a colour the user explicitly filtered out, at 400%. The colours sum to 500 while the parent says 100.

The unfiltered `queryTopProducts()` path (the no-filter branch) has no filters to forget, so it is unaffected. **The bug only appears once a user touches a filter** — which is exactly why it survived this long.

## The change

The filters are applied in one place and forgotten in two. Extract them so they cannot be forgotten:

```php
private function applyFilters($query, ?int $typeId, ?int $qualityId, ?int $colorId, ?int $sizeId, ?int $edgeId)
{
    if ($typeId !== null)    $query->where('products.product_type_id', $typeId);
    if ($qualityId !== null) $query->where('products.product_quality_id', $qualityId);
    if ($colorId !== null)   $query->where('product_colors.color_id', $colorId);
    if ($sizeId !== null)    $query->where('product_variants.product_size_id', $sizeId);
    if ($edgeId !== null)    $query->where('product_variants.product_edge_id', $edgeId);

    return $query;
}
```

Then use it in all three places:

```php
$query = $this->applyFilters($this->baseQuery($from, $to)->select(...), ...);

$colorsByProduct = $this->applyFilters(
    $this->baseQuery($from, $to)->whereIn('products.id', $productIds), ...
)->leftJoin('colors', ...)->selectRaw(...)->get()->groupBy(...);

$sizesByProduct = $this->applyFilters(
    $this->baseQuery($from, $to)->whereIn('products.id', $productIds), ...
)->leftJoin('product_sizes', ...)->selectRaw(...)->get()->groupBy(...);
```

### Think about whether filtering the breakdown is what you want

There's a genuine product question here, and it's worth two minutes before you code.

With `color_id=red`, the colours breakdown becomes **a single row at 100%** — technically correct and completely useless. Two defensible designs:

- **A — filter everything (recommended).** Consistent: every number in the response describes the same filtered set, and percentages always sum to 100. The colours breakdown degenerates to one row when filtering by colour, which is honest — you asked for one colour.
- **B — filter the total too.** Keep breakdowns unfiltered but compute `$qty` as the sum of the unfiltered breakdown, so percentages are of the *product's* total. Then `total_quantity` and the breakdown mean different things in the same object, which needs a rename to be comprehensible.

Take A. It's the one that can't be misread. If the owner actually wants "red is 20% of Shirvan", that's a different feature with a different name, not an accident of a forgotten `where`.

Also check the `$total` used for the top-level percentage (passed into the `map`) is derived from the filtered set too — chase it and confirm.

## While you're here

`queryTopProducts()` (the unfiltered path) has **no `LIMIT`**, unlike `getFilteredTopProducts()` which has `->limit($limit)`. So `getReport()`'s `top_products` returns *every* product ever ordered, each with full colour and size breakdowns. That's a payload and performance problem, not a correctness one. Note it; fix it if it's cheap, but don't let it expand this step.

## How to verify

Pick a product with at least two colours in the period.

1. **Baseline, no filter:**
   ```bash
   curl -s ... "/api/v1/analytics/top-products?period_from=2026-06-01&period_to=2026-06-30" | jq '.data[0]'
   ```
   Record `total_quantity` and the colours array.
2. **Filter to one colour:**
   ```bash
   curl -s ... "/api/v1/analytics/top-products?period_from=2026-06-01&period_to=2026-06-30&color_id=<red>" | jq '.data[0]'
   ```
   - `colors[]` must contain **only red**.
   - Red's `percentage` must be **100.0**.
   - No percentage anywhere may exceed 100.
3. **Sum check** — for every product in every response, the colours' quantities must sum to `total_quantity`. Same for sizes. Today they don't.
4. Repeat for `size_id` and `edge_id`.
5. Combine two filters (`color_id` + `size_id`) and confirm the invariant still holds.
6. `php artisan cache:clear` between runs — `getReport` caches for 5–60 minutes and you will otherwise test the cache.

## Rollback

Revert the commit. Nothing is written; this is a read path only.
