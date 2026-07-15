# 02 — Validate shipment items against their order

`StoreShipmentRequest` checks only that IDs exist. It never checks they belong together, so the wrong client can be billed and orders can be over-shipped without limit.

**Severity: High / Effort: 2d / Safe on live: Only in log-only mode. Read the rollout section before writing any code.**

## Why this matters

`app/Http/Requests/Shipment/StoreShipmentRequest.php` lines 16-27 is the entire validation surface:

```php
'client_id'                  => ['required', 'integer', 'exists:clients,id'],
'order_id'                   => ['nullable', 'integer', 'exists:orders,id'],
'shipment_datetime'          => ['required', 'date'],
'notes'                      => ['nullable', 'string', 'max:2000'],

'items'                      => ['required', 'array', 'min:1'],
'items.*.order_item_id'      => ['required', 'integer', 'exists:order_items,id'],
'items.*.product_variant_id' => ['required', 'integer', 'exists:product_variants,id'],
'items.*.quantity'           => ['required', 'integer', 'min:1'],
'items.*.price'              => ['required', 'numeric', 'min:0'],
```

Every rule asks "does this row exist?". None asks "does it belong here?". Four things are unchecked:

**1. `order_item_id` need not belong to `order_id`.** Post `order_id: 5` with an item from order 9 and it is accepted. The `ShipmentItem` row is written against order 9's item while the `Shipment` header says order 5.

**2. `order_id` need not belong to `client_id`.** Post client 3 with order 7 that belongs to client 8. `ShipmentService::create` (`app/Services/ShipmentService.php:49-55`) writes `client_id` from the request straight onto the header. **Client 3 is now billed for client 8's goods**, and it flows directly into the debit ledger, which reads `Shipment.client_id` (`app/Services/ClientDebitService.php:92`).

**3. `product_variant_id` need not match the order item's variant.** Order item 44 is for a 200×300 KREM carpet; ship variant 91, a 160×230 in another colour, against it. Stock leaves for variant 91, the order item counts as fulfilled, and the client is invoiced at whatever `price` was posted for a product they did not order.

**4. `quantity` has no ceiling.** `'min:1'` and nothing else. Order item 44 is for 10 units. Post a shipment of 10 — accepted. Post it again — **also accepted**. Twenty units ship against a ten-unit order.

The second post does not even leave a trace of the overage in the order status. `ShipmentService::syncOrderShippedStatus` (lines 457-459):

```php
$allShipped = $order->items->every(
    fn ($item) => $item->shipmentItems->sum('quantity') >= $item->quantity
);
```

`>=` means 20 against 10 is "shipped", exactly as 10 against 10 is. The order closes cleanly and the over-ship is invisible. Only the warehouse stock, drawn down twice, records that anything happened — and step 03 explains why even that check does not hold.

Note that stock is *not* the backstop here. `assertSufficientStock` only asks whether the warehouse has the goods, never whether the order called for them. A warehouse with 20 units in stock will happily ship all 20 against a 10-unit order.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | Role |
|---|---|---|
| `app/Http/Requests/Shipment/StoreShipmentRequest.php` | 14-28 | Add `withValidator()` here. |
| `app/Http/Controllers/Api/V1/ShipmentImportController.php` | 26-33, 143-144, 157 | **Read first.** The correct remainder logic already exists here. Reuse it. |
| `app/Services/ShipmentService.php` | 457-459 | Context only — the `>=` that hides the overage. Do not change it in this step. |

## Reuse the logic that already exists

`ShipmentImportController` is the "import from stock" wizard that populates the shipment screen. It already computes exactly the constraint the validator needs, and it is correct. Its docblock (lines 18-19) states the rule:

> "Shippable" means: (order_qty - shipped_qty) > 0 AND stock_qty > 0.
> available_quantity = min(order_qty - shipped_qty, stock_qty).

The shared fragments, lines 26-33:

```php
/** Inline subquery: shipped quantity per order_item. */
private const SHIPPED_SUB = '(SELECT order_item_id, COALESCE(SUM(quantity), 0) AS shipped_qty
    FROM shipment_items GROUP BY order_item_id)';

/** Inline subquery: current stock per product_variant. */
private const STOCK_SUB = '(SELECT product_variant_id,
    COALESCE(SUM(CASE WHEN movement_type = \'in\' THEN quantity ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN movement_type = \'out\' THEN quantity ELSE 0 END), 0) AS stock
    FROM stock_movements GROUP BY product_variant_id)';
```

And the ceiling itself, line 157:

```php
DB::raw('LEAST(oi.quantity - COALESCE(si.shipped_qty, 0), sm.stock) AS available_quantity'),
```

**This is the number the UI already shows the user as the maximum they may ship.** The bug is that nothing enforces it server-side. The validator's job is to re-check the same rule the wizard already applied client-side.

Two notes on scope:

- The validator only needs the **order remainder** half: `oi.quantity - COALESCE(si.shipped_qty, 0)`. The **stock** half is step 03's concern, and doing it here would duplicate that check. Keep them separate.
- `SHIPPED_SUB` sums *all* shipment items for an order item with no date or status filter. That is the right semantics — every unit ever shipped counts against the order.

Do not copy-paste the constants. Move them somewhere both callers can reach — a small `OrderItemAvailability` query class, or public constants on `ShipmentImportController` referenced from the request. A copy will drift.

## The change

Add `withValidator()` to `StoreShipmentRequest`. Keep `rules()` as-is; the `exists:` rules must still run first, because `withValidator` closures execute after the rule set and you do not want to query with IDs that do not resolve.

```php
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Validator;

public function withValidator(Validator $validator): void
{
    $validator->after(function (Validator $v) {
        if ($v->errors()->isNotEmpty()) {
            return;   // IDs did not resolve; the checks below would be meaningless
        }

        $violations = [];
        $data       = $v->getData();

        // ── Order belongs to client ────────────────────────────────────────
        if (! empty($data['order_id'])) {
            $order = Order::find($data['order_id']);
            if ($order && (int) $order->client_id !== (int) $data['client_id']) {
                $violations['order_id'] = sprintf(
                    'Order #%d belongs to client #%d, not client #%d.',
                    $order->id, $order->client_id, $data['client_id']
                );
            }
        }

        // ── Per-item checks ────────────────────────────────────────────────
        // Sum requested quantity per order_item first: two lines against the
        // same order item must be checked against their combined total, not
        // each on its own.
        $requestedPerOrderItem = [];
        foreach ($data['items'] ?? [] as $item) {
            $id = (int) $item['order_item_id'];
            $requestedPerOrderItem[$id] = ($requestedPerOrderItem[$id] ?? 0) + (int) $item['quantity'];
        }

        $orderItems = OrderItem::with('order')
            ->whereIn('id', array_keys($requestedPerOrderItem))
            ->get()
            ->keyBy('id');

        $shippedPerOrderItem = DB::table('shipment_items')
            ->whereIn('order_item_id', array_keys($requestedPerOrderItem))
            ->groupBy('order_item_id')
            ->pluck(DB::raw('COALESCE(SUM(quantity), 0)'), 'order_item_id');

        foreach ($data['items'] ?? [] as $index => $item) {
            $orderItem = $orderItems->get((int) $item['order_item_id']);
            if (! $orderItem) {
                continue;   // exists: rule already flagged it
            }

            // order_item belongs to the shipment's order
            if (! empty($data['order_id'])
                && (int) $orderItem->order_id !== (int) $data['order_id']) {
                $violations["items.{$index}.order_item_id"] = sprintf(
                    'Order item #%d belongs to order #%d, not order #%d.',
                    $orderItem->id, $orderItem->order_id, $data['order_id']
                );
            }

            // order_item's order belongs to the billed client
            if ((int) $orderItem->order?->client_id !== (int) $data['client_id']) {
                $violations["items.{$index}.order_item_id"] = sprintf(
                    'Order item #%d belongs to client #%d, not client #%d.',
                    $orderItem->id, $orderItem->order?->client_id, $data['client_id']
                );
            }

            // variant matches what was ordered
            if ((int) $orderItem->product_variant_id !== (int) $item['product_variant_id']) {
                $violations["items.{$index}.product_variant_id"] = sprintf(
                    'Order item #%d is for variant #%d, not variant #%d.',
                    $orderItem->id, $orderItem->product_variant_id, $item['product_variant_id']
                );
            }
        }

        // ── Over-shipping, checked per order_item across all lines ─────────
        foreach ($requestedPerOrderItem as $orderItemId => $requested) {
            $orderItem = $orderItems->get($orderItemId);
            if (! $orderItem) {
                continue;
            }

            $shipped   = (int) ($shippedPerOrderItem[$orderItemId] ?? 0);
            $remaining = $orderItem->quantity - $shipped;

            if ($requested > $remaining) {
                $violations["order_item.{$orderItemId}.quantity"] = sprintf(
                    'Order item #%d: %d requested, only %d unshipped (ordered %d, already shipped %d).',
                    $orderItemId, $requested, max(0, $remaining), $orderItem->quantity, $shipped
                );
            }
        }

        $this->reportViolations($violations, $v);
    });
}
```

Note the over-ship check is keyed by **order item**, not by request index. Two lines of 6 against the same 10-unit order item must fail on their combined 12, and a per-index check would pass both. This is the same accumulation mistake step 03 describes in `assertSufficientStock` — do not repeat it here.

`OrderItem` has `order_id`, `product_variant_id` and `quantity` in `$fillable` (`app/Models/OrderItem.php:11-15`) and an `order()` relation at line 26, so all the reads above are available.

### Rollout: log-only first. This is not optional.

The live app may already be posting shipments that these checks would reject. Not hypothetically — the four gaps have been open for the life of this endpoint, and the "wrong variant" and "over-ship" cases are exactly what an unvalidated UI produces. If you deploy hard enforcement and the warehouse tablet starts returning 422 mid-shift, loading stops and you have made things worse than the bug.

Ship the switch, default to log-only, and leave it there for **at least one full week covering a shipping-heavy day**:

```php
private function reportViolations(array $violations, Validator $v): void
{
    if ($violations === []) {
        return;
    }

    if (! config('shipments.enforce_item_validation', false)) {
        Log::warning('shipment.validation.would_reject', [
            'user_id'    => $this->user()?->id,
            'client_id'  => $this->input('client_id'),
            'order_id'   => $this->input('order_id'),
            'violations' => $violations,
            'payload'    => $this->except(['notes']),
        ]);

        return;   // request proceeds exactly as it does today
    }

    foreach ($violations as $key => $message) {
        $v->errors()->add($key, $message);
    }
}
```

Add to `config/shipments.php` (create it):

```php
return [
    // Phase 1 step 02: flip to true only after a week of clean logs.
    'enforce_item_validation' => env('SHIPMENTS_ENFORCE_ITEM_VALIDATION', false),
];
```

Log-only mode changes nothing about the response. Same status, same body, same side effects. The only new behaviour is a log line.

Then read the logs. `grep 'shipment.validation.would_reject' storage/logs/laravel.log`. Every hit is either a real bug you are about to start blocking, or a false positive in your validator. **You must know which, for every distinct violation type, before flipping the flag.** If the warehouse legitimately over-ships by a unit to replace a defect, that is a business rule the validator does not yet know about, and enforcing it blind will block real work. Find that out from the logs, not from a stopped production line.

Flip `SHIPMENTS_ENFORCE_ITEM_VALIDATION=true` only when a week of logs is either empty or fully understood. Flipping back is an env change and a config cache clear — no deploy.

## How to verify

No test suite. Use staging with a production-shaped dataset, and a real bearer token.

**Set up.** Find a client with an order and an unshipped item:

```sql
SELECT oi.id AS order_item_id, oi.order_id, o.client_id, oi.product_variant_id,
       oi.quantity,
       COALESCE((SELECT SUM(quantity) FROM shipment_items WHERE order_item_id = oi.id), 0) AS shipped
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
HAVING shipped < oi.quantity
LIMIT 5;
```

**In log-only mode** (`enforce_item_validation = false`), each of these must return **201** and write one `shipment.validation.would_reject` line:

```bash
# Wrong client for the order — should log, must not 422 yet
curl -X POST https://staging/api/v1/shipments \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"client_id": <a DIFFERENT client>, "order_id": <order_id>,
       "shipment_datetime": "2026-07-14T10:00:00Z",
       "items": [{"order_item_id": <order_item_id>, "product_variant_id": <variant_id>,
                  "quantity": 1, "price": 10.00}]}'
```

Check the log names the right violation, then `DELETE` the created shipment rows or restore the staging snapshot — log-only mode really does create them.

**Then set `enforce_item_validation = true`** and re-run. Each must now return **422** with the violation under the right key, and **no `shipments` row must be written**:

```sql
SELECT MAX(id) FROM shipments;   -- before and after; must be unchanged
```

Cover all five cases:

1. **Wrong client for order** → 422 on `order_id`
2. **Order item from a different order** → 422 on `items.0.order_item_id`
3. **Variant not matching the order item** → 422 on `items.0.product_variant_id`
4. **Quantity over the remainder** — post `quantity: <remaining + 1>` → 422 on `order_item.<id>.quantity`
5. **Two lines against one order item, each within the remainder but over it combined** — for a 10-unit item with 0 shipped, post two lines of 6 → 422. This is the case a naive validator misses; confirm it explicitly.

**Then confirm the happy path still works.** Post a valid shipment for the exact remaining quantity → 201. Then post the same again → 422 (nothing remains). Check the DB:

```sql
SELECT order_item_id, SUM(quantity) FROM shipment_items
WHERE order_item_id = <order_item_id> GROUP BY order_item_id;
-- must equal order_items.quantity, never exceed it
```

**Finally, exercise the real UI.** Drive the import-from-stock wizard end to end on staging and ship a real order. The wizard's `available_quantity` and the validator's remainder must agree — if the wizard offers a number the validator rejects, you have a bug in one of them, and the whole point of reusing `ShipmentImportController`'s logic is that they cannot disagree.

## Rollback

- **In log-only mode:** nothing to roll back. Behaviour is unchanged.
- **After enforcement:** set `SHIPMENTS_ENFORCE_ITEM_VALIDATION=false`, run `php artisan config:clear`. Instant, no deploy, no migration. This is the whole reason for the flag.
- **Code:** `git revert`. No schema change, nothing persisted.

If enforcement causes trouble mid-shift, **flip the flag, do not debug live**. The bug has been there for months; another day costs little next to a stopped warehouse.

## Depends on / blocks

- **Depends on:** nothing. Can run in parallel with 01.
- **Blocks:** nothing hard. Sequence it with 03 — that step reworks `assertSufficientStock` in `ShipmentService`, which is the *stock* half of `LEAST(remainder, stock)`. Together they enforce the full rule the import wizard already advertises. Neither is complete alone.
- **Note:** the `>=` at `ShipmentService.php:457-459` stays. Once over-shipping is blocked at the door, `>=` and `==` are equivalent and changing it is churn. If you want it tightened, do it in phase-2 with the `production_events` work, not here.
