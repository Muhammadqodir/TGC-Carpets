# 03 — Move the stock check inside the transaction and make it accumulate

`ShipmentService` checks stock outside the transaction, re-reads the balance per line without accumulating, and takes no locks. Two lines of the same variant both pass against the same balance, and stock goes negative.

**Severity: High / Effort: 3d / Safe on live: Yes — it only rejects shipments that were already impossible.**

## Why this matters

Three defects compound in `app/Services/ShipmentService.php`.

**1. The check runs outside the transaction.** Line 41, then line 45:

```php
public function create(array $data, int $userId): Shipment
{
    $this->assertSufficientStock($data['items']);        // line 41 — outside

    $warehouseDocId = null;

    $shipment = DB::transaction(function () use (...) {  // line 45 — transaction starts here
```

Everything between the check and the writes is a window. Two concurrent requests both check, both pass, both write.

**2. The check does not accumulate.** Lines 404-423:

```php
private function assertSufficientStock(array $items): void
{
    $errors = [];

    foreach ($items as $index => $itemData) {
        $variantId    = (int) $itemData['product_variant_id'];
        $requested    = (int) $itemData['quantity'];
        $currentStock = $this->getStock($variantId);      // re-read, per line

        if ($currentStock < $requested) {
            $errors["items.{$index}.quantity"] = [
                "Insufficient stock for variant ID {$variantId}. Available: {$currentStock}, Requested: {$requested}.",
            ];
        }
    }

    if (! empty($errors)) {
        throw ValidationException::withMessages($errors);
    }
}
```

`getStock()` (lines 425-438) re-reads the stock movement sum from scratch on every iteration. Nothing is subtracted as the loop proceeds, because nothing has been written yet — the writes all happen later, inside the transaction.

**This does not need concurrency to break. One request is enough.** Variant 77 has **10** in stock. Post a single shipment with two lines, both for variant 77, each quantity **6**:

- Line 0: `getStock(77)` → 10. `10 < 6`? No. Passes.
- Line 1: `getStock(77)` → **10 again**. `10 < 6`? No. Passes.
- `$errors` is empty. The transaction runs and writes **two** `out` movements of 6.
- Stock is now `10 - 12 = -2`.

Twelve carpets ship out of a warehouse holding ten. The API returns 201. Nothing logs a warning.

This is not exotic — a shipment naturally has one line per order item, and two order items for the same variant across two orders for one client is an ordinary Tuesday.

**3. No locks anywhere.** Verified: `grep -rn 'lockForUpdate\|sharedLock' app/` returns hits in `WarehouseDocumentService`, `ProductionBatchService` and `ProductVariantService` only. `ShipmentService` takes no locks at all. Even with defects 1 and 2 fixed, two concurrent single-line requests for the same variant both read 10, both pass, both write 6.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | Role |
|---|---|---|
| `app/Services/ShipmentService.php` | 39-45 | Move the check inside the transaction. |
| `app/Services/ShipmentService.php` | 404-423 | `assertSufficientStock` — rewrite to accumulate. |
| `app/Services/ShipmentService.php` | 425-438 | `getStock` — the per-variant sum. |
| `app/Services/ShipmentService.php` | 67-96 | The write loop — resolve the variant once, share it. |

`app/Services/WarehouseDocumentService.php` has the same `getStock` (lines 244-257) and the same non-accumulating `assertSufficientStock` (lines 209-242). **Leave it alone in this step.** It has a different bug on top (step 04) and fixing both at once makes the change unreviewable. Note the duplication and move on.

## The change

### 1. Aggregate per variant, then check once each

```php
// intended — replaces lines 404-423
/**
 * @param  array<int, array{product_variant_id: int|string, quantity: int|string}>  $items
 * @return array<int, int>  variantId => total requested, for reuse by the caller
 */
private function assertSufficientStock(array $items): array
{
    // Sum every line per variant BEFORE checking. Two lines of the same
    // variant must be checked against their combined total.
    $requestedPerVariant = [];
    $lineIndexes         = [];

    foreach ($items as $index => $itemData) {
        $variantId = (int) $itemData['product_variant_id'];
        $requestedPerVariant[$variantId] = ($requestedPerVariant[$variantId] ?? 0) + (int) $itemData['quantity'];
        $lineIndexes[$variantId][]       = $index;
    }

    // Lock all involved variant rows in a stable order to avoid deadlocks
    // between two shipments touching an overlapping set of variants.
    $variantIds = array_keys($requestedPerVariant);
    sort($variantIds);

    ProductVariant::whereIn('id', $variantIds)
        ->orderBy('id')
        ->lockForUpdate()
        ->get();

    $errors = [];

    foreach ($requestedPerVariant as $variantId => $requested) {
        $currentStock = $this->getStock($variantId);

        if ($currentStock < $requested) {
            // Attach the error to the first line for this variant so the UI
            // has somewhere to put it.
            $firstIndex = $lineIndexes[$variantId][0];
            $lineCount  = count($lineIndexes[$variantId]);

            $errors["items.{$firstIndex}.quantity"] = [
                $lineCount > 1
                    ? "Insufficient stock for variant ID {$variantId}. Available: {$currentStock}, Requested: {$requested} across {$lineCount} lines."
                    : "Insufficient stock for variant ID {$variantId}. Available: {$currentStock}, Requested: {$requested}.",
            ];
        }
    }

    if (! empty($errors)) {
        throw ValidationException::withMessages($errors);
    }

    return $requestedPerVariant;
}
```

Add `use App\Models\ProductVariant;` to the imports.

Three things worth being deliberate about:

- **`sort($variantIds)` before locking.** Two shipments touching variants {5, 9} and {9, 5} in opposite orders deadlock. A stable order makes that impossible. The `orderBy('id')` on the query is belt-and-braces for the same reason.
- **The multi-line error message names the aggregate.** "Requested: 12 across 2 lines" tells the user why a shipment they think is two 6s failed against a stock of 10. "Requested: 6" would look like a bug in the error message.
- **Returning `$requestedPerVariant`** lets the caller reuse the aggregation. Optional, but it makes the relationship between check and write explicit.

### 2. Move the call inside the transaction

```php
// current — lines 39-45
public function create(array $data, int $userId): Shipment
{
    $this->assertSufficientStock($data['items']);

    $warehouseDocId = null;

    $shipment = DB::transaction(function () use ($data, $userId, &$warehouseDocId): Shipment {
        $shipmentDate = Carbon::parse($data['shipment_datetime']);

// intended
public function create(array $data, int $userId): Shipment
{
    $warehouseDocId = null;

    $shipment = DB::transaction(function () use ($data, $userId, &$warehouseDocId): Shipment {
        // Inside the transaction, and holding row locks, so the balance we
        // read is the balance we write against.
        $this->assertSufficientStock($data['items']);

        $shipmentDate = Carbon::parse($data['shipment_datetime']);
```

`ValidationException` thrown inside `DB::transaction` rolls back and propagates, so Laravel still renders a 422. Behaviour from the client's point of view is unchanged for the rejection case. Confirm this in verification rather than trusting it.

### 3. Resolve the variant once, share it between check and write

The write loop (lines 67-96) currently re-derives `$variantId` from the raw payload:

```php
foreach ($data['items'] as $itemData) {
    $variantId = (int) $itemData['product_variant_id'];
```

That happens to agree with the check today, because both cast the same field. The audit asked for the variant to be resolved once and shared, and the reason is worth stating plainly: **the check and the write must not be able to disagree about which row they mean.** Today they cannot, because neither resolves anything — both trust the ID. Step 04 is about a *different* code path where resolution does happen and does disagree.

So: do not manufacture a resolution step that does not exist. What you should do is make the shared identity explicit, so a future edit cannot silently split them:

```php
// intended — top of the transaction
$requestedPerVariant = $this->assertSufficientStock($data['items']);

// ... and in the write loop, assert the invariant holds
foreach ($data['items'] as $itemData) {
    $variantId = (int) $itemData['product_variant_id'];

    if (! array_key_exists($variantId, $requestedPerVariant)) {
        // Cannot happen unless the check and the write disagree about the
        // payload. If it ever does, fail loudly inside the transaction.
        throw new \LogicException(
            "Variant {$variantId} was written but never stock-checked."
        );
    }
```

This is a guard, not a fix. It costs nothing and it converts a future silent divergence into a rollback.

### What this step does not fix

Locking `product_variants` rows is **the wrong lock**. The stock balance does not live there — it is a `SUM` over `stock_movements` (lines 425-438). Locking the variant row is a *proxy*: it serialises anyone who follows the same convention, and it is worth nothing against a writer who does not.

Two consequences you must accept:

- Every writer to `stock_movements` must take the same lock or the guarantee evaporates. `WarehouseDocumentService` does **not** currently take it. So this step makes concurrent *shipments* safe against each other, and does **not** make a shipment safe against a concurrent warehouse document. That is a real remaining hole.
- The `SUM` over `stock_movements` grows without bound and is recomputed per variant per request.

The real fix is a `product_variant_stock` balance row you lock and update directly, which is **phase-2**. This step is the interim: it closes the single-request bug completely (defect 2, which needs no concurrency at all), closes shipment-vs-shipment races, and leaves shipment-vs-warehouse-document for phase-2. Write that trade-off in a comment above the lock so the next reader knows the lock is deliberate and insufficient:

```php
// INTERIM (phase-1 step 03): product_variants is a proxy lock. The real
// balance is a SUM over stock_movements. Every writer must take this lock
// for it to mean anything — WarehouseDocumentService currently does not.
// Phase-2 replaces this with a lockable product_variant_stock balance row.
```

## How to verify

No test suite. Staging, restored from a production dump.

**1. The single-request case — this is the important one, and it needs no concurrency.**

Find a variant and note its stock:

```sql
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in'  THEN quantity ELSE 0 END)
     - SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END) AS stock
FROM stock_movements
WHERE product_variant_id = <variant_id>
GROUP BY product_variant_id;
```

Say it returns 10. Post **one** shipment with **two lines of the same variant**, 6 each:

```bash
curl -X POST https://staging/api/v1/shipments \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"client_id": <c>, "order_id": <o>, "shipment_datetime": "2026-07-14T10:00:00Z",
       "items": [
         {"order_item_id": <oi1>, "product_variant_id": <v>, "quantity": 6, "price": 10.00},
         {"order_item_id": <oi2>, "product_variant_id": <v>, "quantity": 6, "price": 10.00}
       ]}'
```

- **Before the change:** 201, and the stock query now returns **-2**.
- **After the change:** 422, message naming "Requested: 12 across 2 lines", and the stock query still returns **10**.

Confirm nothing was written:

```sql
SELECT MAX(id) FROM shipments;             -- unchanged
SELECT MAX(id) FROM warehouse_documents;   -- unchanged, the doc is created inside the same transaction
SELECT MAX(id) FROM stock_movements;       -- unchanged
```

The `warehouse_documents` check matters: it proves the rollback covers the companion document created at lines 58-63, not just the shipment header.

**2. Two lines of the same variant that legitimately fit.** Stock 10, two lines of 4 → 201, stock ends at 2. This is the regression guard — the aggregation must not reject valid shipments.

**3. The concurrency case.** Two terminals, same variant, stock 10, each posting a single line of 6:

```bash
# Terminal A and B, fired as close together as you can manage
curl -X POST https://staging/api/v1/shipments -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"client_id": <c>, "order_id": <o>, "shipment_datetime": "2026-07-14T10:00:00Z",
       "items": [{"order_item_id": <oi>, "product_variant_id": <v>, "quantity": 6, "price": 10.00}]}' &
```

Exactly one must return 201 and one must return 422. Stock must end at 4, never -2.

Timing this by hand is unreliable. To make it deterministic, open a MySQL session and hold the lock yourself:

```sql
START TRANSACTION;
SELECT * FROM product_variants WHERE id = <v> FOR UPDATE;
-- now fire the curl; it must BLOCK here, not proceed
-- then:
ROLLBACK;
-- the curl should now complete
```

If the request does not block, the lock is not being taken and the code is wrong.

**4. Stock never goes negative, across the board.** After exercising staging, this must return zero rows:

```sql
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in'  THEN quantity ELSE 0 END)
     - SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END) AS stock
FROM stock_movements
GROUP BY product_variant_id
HAVING stock < 0;
```

**Run this against the production database before you start.** Any variant already negative is a shipment that has already over-shipped — this change cannot repair it, only stop the next one. Hand that list to whoever owns the physical count; those are real carpets that either exist or do not.

**5. Confirm 422 still renders as 422.** The exception now throws from inside `DB::transaction`. Check the response body is the normal Laravel validation shape with the error under `items.0.quantity`, not a 500.

## Rollback

Pure code change, no migration. `git revert` and deploy.

The only new failure mode is **lock contention**: a shipment now waits on `product_variants` rows another shipment holds. Under MySQL's default `innodb_lock_wait_timeout` of 50s, a slow transaction could surface as a timeout on a second request. The transaction here is short — a handful of inserts, with PDF generation deliberately outside it (lines 113-157) — so this should not bite. Watch the logs for `Lock wait timeout exceeded` for the first day. If it appears, that is a signal the transaction is doing more than it should, not a reason to abandon locking.

Nothing is persisted differently, so rollback is clean at any point.

## Depends on / blocks

- **Depends on:** nothing strictly. Best done **after step 02**, which adds the order-remainder half of the same rule — 02 and 03 together enforce `LEAST(order_remainder, stock)`, the constraint `ShipmentImportController` already shows the user at line 157.
- **Blocks:** nothing in phase-1.
- **Superseded by:** phase-2's `product_variant_stock` balance row, which replaces the proxy lock with a real one and makes `getStock()` an O(1) read. Do not over-invest here — this step is a stopgap and should read like one.
- **Leaves open:** `WarehouseDocumentService` still has the same non-accumulating check (lines 209-242) and does not take the variant lock. Step 04 touches that file for a different reason; the stock-check duplication there is phase-2's problem.
