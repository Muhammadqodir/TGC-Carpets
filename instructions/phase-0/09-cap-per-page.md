# Cap `per_page` — one query parameter can take the server down

Sixteen paginated endpoints accept an unbounded `per_page`. `?per_page=1000000` on `/stock/variants` runs three correlated subqueries per variant across the whole table.

**Severity:** Medium · **Effort:** 30 min · **Safe on live:** Yes

**Finding:** LOGIC-6 · **Depends on:** nothing

**Status:** ✅ Implemented 2026-07-15 — see [DEPLOY.md](DEPLOY.md) before shipping.

## Why this matters

Every paginated endpoint does this:

```php
->paginate($request->integer('per_page', 50));
```

There is no ceiling. Any authenticated user — and every operator on the factory floor has a token, since `EnsureRole` is applied to zero routes (STRUCT-4) — can request a million rows.

The worst offender is `StockController::variants` (line 157). Per row it evaluates **three correlated subqueries**: one summing `stock_movements`, one joining `production_batch_items ⋈ order_items ⋈ orders`, one joining `shipment_items ⋈ order_items ⋈ orders`. With no LIMIT to stop it, that runs across the entire variants table.

`StockController::movements` (line 207) is nearly as bad — it eager-loads five relations per movement (`variant.productColor.product`, `variant.productColor.color`, `variant.productSize`, `variant.productEdge`, `user`).

This isn't malice-only. A client bug that sends `per_page=0` or a mistyped value, or a well-meaning "export everything" feature, produces the same outage.

## Files to change

All sixteen call sites (`grep -rn "per_page" app/Http/Controllers/Api/V1/`):

| File | Line(s) |
|---|---|
| `ClientDebitController.php` | 32 |
| `ClientController.php` | 24 |
| `EmployeeController.php` | 27 |
| `DefectDocumentController.php` | 29 |
| `OrderController.php` | 68 |
| `PaymentController.php` | 23 |
| `MachineController.php` | 19 |
| `ProductController.php` | 28 |
| `ProductColorController.php` | 19 |
| `RawMaterialController.php` | 50, 126 |
| `ProductionBatchController.php` | 49 |
| `StockController.php` | 46, 157, 207 |
| `ShipmentController.php` | 35, 95 |
| `WarehouseDocumentController.php` | 28 |
| `ProductVariantController.php` | 26 |

## The change

Don't sprinkle `min()` across sixteen files — that's sixteen chances to forget one, and the next controller added won't have it. Put it in one place.

Add a helper to `app/Http/Controllers/Controller.php`:

```php
/**
 * Resolve a per_page value, clamped to a sane range.
 * Guards against ?per_page=1000000 taking the server down.
 */
protected function perPage(Request $request, int $default = 50, int $max = 200): int
{
    $value = $request->integer('per_page', $default);

    return max(1, min($value, $max));
}
```

Then replace every call site:

```php
// before
->paginate($request->integer('per_page', 50));

// after
->paginate($this->perPage($request));

// where the default differs (RawMaterialController.php:126)
->paginate($this->perPage($request, 30));
```

The `max(1, ...)` matters: `$request->integer('per_page')` returns `0` for `?per_page=abc` or `?per_page=0`, and `paginate(0)` behaves badly.

`ClientDebitController.php:32` uses a named argument (`perPage: $request->integer('per_page', 50)`) — adapt rather than blindly find-and-replace.

### Why 200 and not 1000?

50 is the current default and nobody has complained. 200 gives headroom for a legitimate "show more" without letting a single request scan the table. If a genuine export need exists, it should be a dedicated endpoint that streams — not `per_page=100000` on a screen endpoint.

## Related, not fixed here

`StockController::variants`'s three-correlated-subqueries-per-row design is the actual performance problem; capping `per_page` just bounds the blast radius. `phase-2/07` replaces the stock subquery with a `product_variant_stock` balance row, making it O(1) per row. Don't attempt that here.

## How to verify

```bash
# 1. Absurd value — must return 200 rows max, fast
time curl -s -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/stock/variants?per_page=1000000" | jq '.meta.per_page, (.data | length)'
# expect: 200, 200 (or fewer if the table is smaller)

# 2. Junk value — must not 500 or return an empty page
curl -s -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/stock/variants?per_page=abc" | jq '.meta.per_page'
# expect: 50 (the default), not 0

# 3. Zero — must not 500
curl -s -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/stock/variants?per_page=0" | jq '.meta.per_page'
# expect: 1

# 4. Normal value — unchanged
curl -s -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/stock/variants?per_page=25" | jq '.meta.per_page'
# expect: 25
```

5. Check every endpoint in the table above still paginates. A find-and-replace across sixteen files is exactly where a typo hides.
6. Confirm the Flutter client doesn't request more than 200 anywhere:
   ```bash
   grep -rn "per_page" tgc_client/lib --include='*.dart'
   ```
   If it does, that screen will silently start showing 200 rows instead of all of them — find out whether that matters before shipping.

## Rollback

Revert the commit. Nothing is written.
