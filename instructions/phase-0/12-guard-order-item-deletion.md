# Stop order edits from silently orphaning production progress

Editing an order's item list deletes and recreates every `order_item`, which doesn't error — it silently severs the link to any production already tracked against them.

**Severity:** Critical · **Effort:** 15 min · **Safe on live:** Yes — this only *rejects* requests that currently destroy the order↔production link

**Finding:** none (not in the original 14 July audit) — found live on 2026-07-15 while functionally testing the phase-0 fixes on dev.tgc-carpets.uz, by simply editing an order in the app and noticing its production progress disappeared. Same shape as **PROD-1** (`phase-0/06`), just on `Order` instead of `ProductionBatch`.

**Status:** ✅ Implemented 2026-07-15, committed on `dev` (`d77ba8f`), pushed to `origin/dev`. **Not yet deployed to production**, not yet functionally re-tested after the fix. See [DEPLOY.md](DEPLOY.md).

## Why this matters

`app/Services/OrderService.php:46` (`update()`) already guards against deleting order items that have been shipped — `shipment_items.order_item_id` is `restrictOnDelete`, so that path throws and is caught. But nothing guarded the production link:

```php
if (! empty($data['items'])) {
    if ($order->items()->whereHas('shipmentItems')->exists()) {
        throw new \DomainException(/* ... */);
    }

    $order->items()->delete();          // ← production_batch_items.source_order_item_id is nullOnDelete
    $this->syncItems($order, $data['items']);   // ← new order_items get NEW ids
}
```

`production_batch_items.source_order_item_id` (`2026_04_11_000003:15`) is `->nullable()->constrained('order_items')->nullOnDelete()`. So deleting the order's items doesn't throw — it just sets `source_order_item_id = NULL` on every batch item that pointed at them. The batch item itself, and its `produced_quantity`/`defect_quantity`/`warehouse_received_quantity`, are untouched. But the order gets fresh item rows with new ids that no production batch currently references, so every screen that computes an order's production progress via `OrderItem::productionBatchItems()` (e.g. `checkAndAutoCompleteOrders` in `WarehouseDocumentService`, and the order detail screen in the client) now sees nothing. The progress isn't lost — it's orphaned and invisible.

### Failure scenario

An order has 3 line items, 2 of which already have production batches in progress (produced 40/100).

1. Someone edits the order — maybe just to fix a typo in one unrelated line's quantity — and the request includes the full `items` array (the client always sends the full list on edit, not a diff).
2. All 3 `order_items` are deleted and recreated with new ids.
3. The 2 production batches' `source_order_item_id` silently becomes `NULL`.
4. The order detail screen shows 0% production progress on lines that are actually 40% woven. The order can never auto-complete via `checkAndAutoCompleteOrders`, since it computes progress by summing `ProductionBatchItem::where('source_order_item_id', $orderItem->id)` against the order's *current* (new) item ids — which nothing points at anymore.

## The change

`app/Services/OrderService.php` — `update()`. Same guard shape as the existing shipment-items check, added right after it:

```php
if ($order->items()->whereHas('productionBatchItems')->exists()) {
    throw new \DomainException(
        'Buyurtma qatorlari ishlab chiqarish partiyasiga bog\'langan. Mahsulot ro\'yxatini o\'zgartirib bo\'lmaydi.'
    );
}
```

`OrderItem::productionBatchItems()` (`app/Models/OrderItem.php:36`) already exists as a `hasMany(ProductionBatchItem::class, 'source_order_item_id')`, so no model changes needed.

Header-only edits (`client_id`, `status`, `order_date`, `notes`) are unaffected — the guard sits inside the `if (! empty($data['items']))` branch, same as the shipment check next to it.

## How to verify

No test suite. On staging/dev:

1. Create an order, link it to a production batch (however the client normally does this — via `source_order_item_id` on batch creation), print at least one label so `produced_quantity > 0`.
2. `PATCH` the order with a full `items` array (even unchanged) → expect **422** with the Uzbek message, not a silent reset.
3. Confirm the batch item's `source_order_item_id` is unchanged:
   ```sql
   SELECT id, source_order_item_id, produced_quantity FROM production_batch_items WHERE production_batch_id = X;
   ```
4. Create a fresh order with no linked production, edit its items → expect **200**, items replaced normally. Editing an order before production starts must keep working.
5. Edit only `notes`/`status`/`client_id` on an order that *does* have linked production → expect **200**. Header edits must not be blocked.

## Rollback

Revert the commit. The endpoint returns to silently orphaning production links on edit.

## Damage already done

This bug has been live since `OrderService` was written — i.e. for the entire time production has been running, unrelated to today's phase-0 deploy. Find orphaned batch items whose quantities suggest they were once linked to an order:

```sql
-- Production batch items with real production recorded, but no order link.
-- Some of these are legitimate (manual/non-order production), but any that
-- should have an order behind them are victims of this bug.
SELECT id, production_batch_id, product_variant_id,
       planned_quantity, produced_quantity, defect_quantity, warehouse_received_quantity
FROM production_batch_items
WHERE source_order_item_id IS NULL
  AND source_type = 'order_item'
  AND (produced_quantity > 0 OR defect_quantity > 0);
```

Also added to [reconcile-before-deploy.sql](reconcile-before-deploy.sql) (query 7). Run it against production **before** deploying this fix — same "measure before you fix" rule as everything else in phase 0. Report the count to the owner; some orders may have been silently under-reporting progress or failing to auto-complete for a long time.
