# 07 — Stock reservations

Nothing reserves stock at order time, so two orders can be promised the same physical carpet.

**Severity: High / Effort: 2 weeks / Safe on live: No — introduces a new constraint on order and shipment flows; ship in warn-only mode first**

## Why this matters

"Ordered" and "available" are the same number today. There is no reservation concept anywhere in the system, so nothing stops the warehouse from promising one carpet to two clients.

The concrete sequence, all of which the software permits:

1. Warehouse holds 100 carpets of variant X.
2. Client A orders 80. Nothing happens to stock — an order has no effect on any balance.
3. Client B orders 80. The stock screen still shows 100 available, because it is showing physical stock.
4. Both orders are accepted, both are confirmed to the client, both are scheduled.
5. Whoever ships first gets 80. The second shipment finds 20.

Nobody is told anything is wrong until step 5. By then the factory has two clients holding confirmed orders and 20 carpets. The system was never asked whether the carpets were free, because nothing in it can answer that question.

### What `quantity_reserved` actually is

`tgc_backend/app/Http/Controllers/Api/V1/StockController.php` has a field called `quantity_reserved`, which makes it look like reservations exist. They do not. `variants()` (line 88) computes it at line 177:

```php
'quantity_reserved'  => max(0, (int) $row->qty_received - (int) $row->qty_shipped),
```

from two correlated subqueries. `qty_received` (lines 101–107):

```php
$qtyReceivedForActiveOrders = DB::table('production_batch_items as pbi')
    ->join('order_items as oi', 'oi.id', '=', 'pbi.source_order_item_id')
    ->join('orders as o', 'o.id', '=', 'oi.order_id')
    ->selectRaw('COALESCE(SUM(pbi.warehouse_received_quantity), 0)')
    ->whereColumn('pbi.product_variant_id', 'product_variants.id')
    ->where('pbi.source_type', 'order_item')
    ->whereNotIn('o.status', ['canceled', 'shipped']);
```

and `qty_shipped` (lines 110–115) sums `shipment_items.quantity` for the same non-cancelled, non-shipped orders.

Read what that means. It is: *"carpets that were produced against an active order and have physically arrived in the warehouse, minus what has already gone out against those orders."* It is a **backward-looking description of goods that already exist and are already spoken for by production**. It is not a reservation:

- **It only counts carpets that were produced for an order.** The subquery requires `pbi.source_type = 'order_item'` and a join through `production_batch_items`. An order fulfilled from existing warehouse stock — no batch, no production — contributes **zero** to `quantity_reserved`. That is the exact case in the five-step scenario above, and it is the common case for anything kept in stock.
- **It only counts what has already been received.** `warehouse_received_quantity` is the arrival counter. An order placed this morning reserves nothing, because nothing has been made yet. Reservation is supposed to be a claim on the *future*; this measures the past.
- **`max(0, ...)`** clamps a negative to zero. A negative means more was shipped than was received against those orders — a real inconsistency — and the clamp discards the evidence. Whatever caused it stays invisible.
- **Nothing enforces it.** No code reads `quantity_reserved` and refuses anything. It is a display field on one screen.

So the name promises a guarantee that the arithmetic cannot make. It is a derived approximation of "production output currently earmarked", and the danger is that it reads like a reservation to anyone using the screen. If the reservation work stalls, **rename this field** — `quantity_produced_for_orders` is what it is, and the honest name costs nothing.

## Files to change

- new migration `xxxx_create_stock_reservations_table.php`
- new `tgc_backend/app/Models/StockReservation.php`
- new `tgc_backend/app/Services/StockReservationService.php`
- `tgc_backend/app/Services/OrderService.php` — `syncItems()` line 86; reserve on order create/update
- `tgc_backend/app/Services/ShipmentService.php` — consume reservations; `assertSufficientStock()` line 404
- `tgc_backend/app/Services/WarehouseDocumentService.php` — `create()` line 28, `assertSufficientStock()`
- `tgc_backend/app/Http/Controllers/Api/V1/StockController.php` — `variants()` line 88, the reserved field at line 177
- `tgc_backend/app/Http/Resources/OrderItemResource.php` — `getStockForVariant()` line 115
- client: order form (must show available, not physical), stock screens

## The change

### 1. The table

```sql
CREATE TABLE stock_reservations (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    product_variant_id BIGINT UNSIGNED NOT NULL,
    order_item_id BIGINT UNSIGNED NOT NULL,
    quantity INT UNSIGNED NOT NULL,
    status ENUM('active','fulfilled','released','expired') NOT NULL DEFAULT 'active',
    reserved_by BIGINT UNSIGNED NOT NULL,
    reserved_at DATETIME NOT NULL,
    released_at DATETIME NULL,
    release_reason VARCHAR(255) NULL,
    expires_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,

    KEY idx_variant_status (product_variant_id, status),
    KEY idx_order_item (order_item_id),
    CONSTRAINT fk_res_variant FOREIGN KEY (product_variant_id) REFERENCES product_variants(id),
    CONSTRAINT fk_res_order_item FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE CASCADE
);
```

- A reservation is a **claim by an order line on a quantity of a variant**. One row per order line per variant.
- `idx_variant_status` is the hot index — `SUM(quantity) WHERE variant = ? AND status = 'active'` runs on every availability check.
- `expires_at` is optional but worth having: a reservation held by an order nobody is progressing should not block stock forever. Leave it null initially and add a sweep later; the column now saves a migration then.
- `released_at` / `release_reason` keep the history of *why* a claim went away. Do not simply delete rows — the reservation history is how you answer "why did this order lose its stock", and `06-audit-log.md` will not cover a row that never existed.
- `ON DELETE CASCADE` on `order_item_id`: if an order line is deleted, its claim is meaningless. Note `OrderService::syncItems()` (line 86) replaces items on update — check whether it deletes and recreates rows, because that would silently drop and recreate reservations, losing the reserved date. Fix that or reservations will churn on every order edit.

### 2. The core definition

Write this once, in one place, and never inline it anywhere:

```
physical  = SUM(stock_movements: in − out)                       -- what is in the building
reserved  = SUM(stock_reservations.quantity WHERE status='active') -- what is promised
available = physical − reserved                                   -- what can be promised
```

`available` is the number the order form must show. `physical` is the number the warehouse screen must show. Today both screens show `physical` and call one of them reserved. Both numbers are legitimate and they answer different questions — the bug is using one where the other is meant.

`available` may be **negative**, and that is information, not an error. It means you have promised more than you hold and must produce the difference. Do not clamp it to zero the way line 177 does. A negative `available` is the single most useful number in this whole file — it is the backorder.

### 3. Reserve at order time

`OrderService::syncItems()` (line 86) is where an order line comes into existence. For each line, create an `active` reservation for the ordered quantity against the variant.

Then answer the question this raises: **what if `available` goes negative — reject the order, or accept it?**

Accept it. This is a factory: an order for carpets that do not exist yet is not an error, it is the business. The reservation records the claim; production satisfies it. Rejecting would break the primary workflow.

But **surface it**. The order form must show, at the moment of entry: "12 available, 80 ordered, 68 to produce." That single sentence is the whole value of this work. Today it says "100 in stock" to two people at once.

This also means reservations must not be gated on stock being present, which in turn means the reservation table can hold claims exceeding physical stock indefinitely. That is correct and intended.

### 4. Consume at shipment time

When a shipment ships against an order line, the reservation is consumed: reduce the active reservation by the shipped quantity, or mark it `fulfilled` when fully shipped. Physical stock drops by the same amount via the existing `stock_movements` path.

The invariant to hold: **shipping must reduce `physical` and `reserved` by the same amount, so `available` does not move.** If `available` jumps when a shipment goes out, you have double-counted — the goods left, but so did the claim on them, and the two cancel. Assert this in a test; it is the reservation equivalent of the ledger's return-to-zero.

Release reservations when:
- the order is cancelled → `released`, reason `order_cancelled`
- the order line is deleted or reduced → `released` or reduced
- the order is completed/shipped → `fulfilled`

`ShipmentService::assertSufficientStock()` (line 404) currently checks physical stock. Decide whether shipping should check `physical` (can I physically send it) or `available` (is it mine to send). It must remain `physical` — you can always ship what you hold; the reservation conflict was supposed to be caught at order time. Checking `available` here would block a legitimate shipment because a *different* order has a claim, which is a worse failure than the one being fixed.

### 5. Interaction with the Phase 2 `product_variant_stock` balance row

Phase 2 introduces a materialised balance row per variant, reconcilable against `stock_movements`. Reservations must sit **alongside** it, not inside it:

- `product_variant_stock` holds `physical` — the reconcilable cache of the movement ledger. Its authority is `SUM(stock_movements)`, and that reconciliation is the whole point of the Phase 2 design.
- Reservations are **not** movements. Reserving a carpet moves nothing; the carpet does not change location or ownership. A reservation must never write a `stock_movement`, or the ledger stops meaning "physical goods" and `SUM(movements)` stops reconciling to the warehouse floor. This is the mistake to avoid, and it is tempting because it makes `available` a single column read.
- If a `quantity_reserved` column is added to `product_variant_stock` as a cache, its authority is `SUM(stock_reservations WHERE status='active')` and it needs its own reconciliation, exactly parallel to the physical one. Two caches, two reconciliations, one table. That is fine — just do not let anyone conclude that because both live on `product_variant_stock`, they come from the same ledger.

If Phase 2 has not landed, compute `reserved` as a correlated subquery in `StockController::variants()` alongside the existing `$qtyWarehouse` (lines 91–96) and add the cache later. Do not wait for Phase 2 to start.

### 6. Replace `quantity_reserved`

Once real reservations exist, line 177 becomes:

```php
'quantity_physical'  => (int) $row->quantity_warehouse,
'quantity_reserved'  => (int) $row->quantity_reserved,      // from stock_reservations
'quantity_available' => (int) $row->quantity_warehouse - (int) $row->quantity_reserved,
```

Keep the old approximation available under its honest name (`quantity_produced_for_orders`) for one release if any screen depends on it, then delete. Note the API contract changes for the client — `quantity_reserved` keeps its name but changes meaning, which is the most dangerous kind of change. Consider shipping the new field under a new name and retiring the old one explicitly rather than silently redefining it.

`OrderItemResource::getStockForVariant()` (line 115) also reports stock to the order screen and must switch to `available`.

### 7. Roll out in warn-only mode

1. Table + service + backfill. Nothing reads it.
2. Reserve on order create, release on cancel. Still nothing reads it. Watch for a week: does `reserved` track what the floor believes is promised?
3. Expose `available` on the stock screen **next to** physical, without changing any behaviour. Let the warehouse tell you whether the number is right. They will know immediately.
4. Show the "12 available, 80 ordered, 68 to produce" line on the order form.
5. Only then consider any hard block.

Step 3 is the real test. A reservation system whose numbers the warehouse does not believe will be worked around, and a worked-around reservation system is worse than none because the screens now lie with authority.

### Backfill

For every active order line not yet fully shipped, create an `active` reservation for the unshipped quantity:

```sql
INSERT INTO stock_reservations
    (product_variant_id, order_item_id, quantity, status, reserved_by, reserved_at, created_at, updated_at)
SELECT oi.product_variant_id,
       oi.id,
       oi.quantity - COALESCE(shipped.qty, 0),
       'active',
       o.user_id,             -- confirm the column that holds the order's creator
       o.created_at,
       NOW(), NOW()
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
LEFT JOIN (
    SELECT order_item_id, SUM(quantity) AS qty
    FROM shipment_items
    GROUP BY order_item_id
) shipped ON shipped.order_item_id = oi.id
WHERE o.status NOT IN ('canceled', 'shipped')
  AND oi.quantity - COALESCE(shipped.qty, 0) > 0;
```

Verify `orders.user_id` and `order_items.product_variant_id` exist under those names before running. Expect the resulting `available` to be negative for some variants on day one — that is the double-promising that has already happened, surfacing for the first time. Do not "fix" it by adjusting the backfill; take the list to the factory. That list is this project's first deliverable.

## How to verify

1. Order 80 of a variant with 100 physical → `physical` 100, `reserved` 80, `available` 20.
2. Second order for 80 → `available` −60, and the order form says so before the user confirms. This is the scenario in Why this matters; run it literally.
3. Ship 80 against the first order → `physical` 20, `reserved` 80 → 0 for that line... **and `available` stays −60.** If `available` moves, reservations are being double-counted.
4. Cancel the second order → reservation `released` with a reason, `available` returns to 20.
5. Delete an order line → its reservation goes, `available` recovers.
6. Reduce an order line 80 → 50 → reservation follows to 50. Check `OrderService::syncItems()` does not delete-and-recreate and lose `reserved_at`.
7. A warehouse `out` document reduces `physical` but **not** `reserved`. `available` drops. Correct: goods left without an order consuming a claim.
8. No `stock_movement` row is ever written by a reservation. Assert this in a test — it is the Phase 2 boundary.
9. `SUM(active reservations)` per variant equals the sum of unshipped quantities on active order lines. Run this as a reconciliation query weekly during rollout.
10. Backfill: the list of variants with negative `available`. Review every one with the factory before step 3.

## Rollback

Steps 1–2 are additive and unread — drop the table. Step 3 is display-only; revert the resource. Step 4 changes what the order form tells users but blocks nothing, so it is still a code revert.

The rollback risk is entirely in step 5 (a hard block), which is why it is deliberately last and unscheduled. Do not implement a hard block in this two-week window. Ship visibility first, let it run a month, then decide whether a block is wanted — by then the factory will tell you.

## Depends on / blocks

- **Depends on `01-tests-and-ci.md`.** This touches order creation and shipping, the two paths that must not break.
- **Depends on Phase 2** only softly. It composes with `product_variant_stock` (see step 5) but does not need it. Do not sequence this behind Phase 2 — the negative-`available` list is worth having sooner.
- **Depends on `05-signed-adjustment-documents.md`** in spirit: `available = physical − reserved` inherits any error in `physical`, and until adjustments can go down, `physical` cannot be corrected downward. Reserving against a number known to be too high produces confident wrong answers. Do 05 first — it is three days.
- **Improved by `02-production-units-serials.md`.** With serials, a reservation can eventually name specific carpets rather than a count, which makes allocation exact. Not required. Do not build serial-level reservations in this pass — quantity-level reservations first, and only go finer if the factory actually needs "this specific carpet is Client A's".
- **Blocks nothing** in Phase 3.
