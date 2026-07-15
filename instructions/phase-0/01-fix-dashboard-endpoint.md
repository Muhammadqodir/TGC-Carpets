# Fix `/dashboard/stats` — it returns HTTP 500 on every request

The dashboard has **two** independent fatal bugs. The first masks the second, so fixing only the import will not fix the endpoint.

**Severity:** Critical · **Effort:** 30 min (bug 1: 5 min; bug 2: see below) · **Safe on live:** Yes — pure bug fix, no schema or contract change

**Finding:** CALC-2 · **Blocks:** nothing · **Depends on:** nothing

## Why this matters

`GET /api/v1/dashboard/stats` (registered at `routes/api.php:65`) is called by the Flutter client at `tgc_client/lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart:25`. It has been down since the `Improved stock calculations` commit. This is not "sometimes wrong" — it is a guaranteed 500 on every call.

## Bug 1 — `StockMovement` is not imported

`app/Http/Controllers/Api/V1/DashboardController.php:43` uses `StockMovement::TYPE_IN`. The file's imports are only:

```php
use App\Http\Controllers\Controller;
use App\Models\WarehouseDocument;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
```

With no import, PHP resolves the name relative to the current namespace, i.e. `App\Http\Controllers\Api\V1\StockMovement` — which does not exist. Result: `Error: Class "App\Http\Controllers\Api\V1\StockMovement" not found` → 500.

**The change.** Add to the imports:

```php
use App\Models\StockMovement;
```

That's it. But do not stop here.

## Bug 2 — `shipment_items.total` does not exist

`DashboardController.php:59`:

```php
$shipmentsAmount = DB::table('shipment_items')
    ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
    ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
    ->sum('shipment_items.total');        // ← this column was dropped
```

Migration `database/migrations/2026_04_16_000001_drop_total_from_shipment_items_table.php` dropped the column:

```php
Schema::table('shipment_items', function (Blueprint $table) {
    $table->dropColumn('total');
});
```

No later migration re-adds it, and `app/Models/ShipmentItem.php` has no `total` in `$fillable` — only `shipment_id`, `order_item_id`, `product_variant_id`, `quantity`, `price`. Confirm for yourself:

```sql
SHOW COLUMNS FROM shipment_items;
```

Once bug 1 is fixed, this line will throw `SQLSTATE[42S22]: Unknown column 'shipment_items.total' in 'field list'` — a 500 from SQL instead of a 500 from PHP.

**The problem:** the line total is now *derived*, not stored. Deriving it correctly means `price × length × width × quantity / 10000` for m² units and `price × quantity` otherwise — which is exactly the formula that CALC-3 says is duplicated across four places with three different rounding rules. Reproducing it here inline would make it a **fifth** copy.

**Pick one:**

- **Option A (recommended).** Drop `shipments_amount` from the response for now, ship the endpoint working, and reinstate it in `phase-1/01` using the shared `lineTotal()` method. The other three metrics are what the dashboard is mostly for.
- **Option B.** Compute it inline now, matching `ClientDebitService::getSummaries` exactly, and accept that `phase-1/01` will rewrite it. Only do this if the owner actively uses the revenue figure daily.

Either way, **do not invent a fifth rounding rule.**

If you take Option A, remove the `$shipmentsAmount` query and the `'shipments_amount' => (float) $shipmentsAmount` line from the response, and tell the client developer so the Flutter model stops expecting the key.

## Known-wrong-but-out-of-scope

Two things in this file are wrong and are deliberately **not** fixed here — they are behaviour changes, not crash fixes, and belong in their own steps:

- `warehouse_stock` (line 40) has no date filter — it nets *all movements ever*, then is returned next to `date_from`/`date_to` as though it were a period figure. Every period shows the identical number. (LOGIC-6.)
- `production_quantity` (line 25) counts warehouse `in` document items, which include supplier deliveries and don't exclude cancelled batches — so it can never reconcile with Production Analytics. (LOGIC-6.)

Leave a `// TODO` referencing this file. Don't quietly change what the numbers mean in the same deploy that makes the endpoint respond at all.

## How to verify

There is no test suite. Do this by hand:

```bash
# 1. Should return 200 with JSON, not a 500
curl -i -H "Authorization: Bearer <token>" \
     "https://<host>/api/v1/dashboard/stats?from=2026-07-01&to=2026-07-31"
```

Then:

2. Confirm `production_quantity` and `shipments_quantity` are non-zero for a period you know had activity.
3. Cross-check `warehouse_stock` against `SELECT COALESCE(SUM(CASE WHEN movement_type='in' THEN quantity ELSE -quantity END),0) FROM stock_movements;` — it should match exactly, since the endpoint runs the same query.
4. Open the dashboard screen in the Flutter app and confirm it renders.

## Rollback

Revert the commit. The endpoint returns to being broken, which is the current state — there is no data to undo, since nothing here writes.
