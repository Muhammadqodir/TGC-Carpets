# 07 — Symmetric FIFO allocation, and stop discarding the remainder

Credit allocates FIFO, debit allocates LIFO, so a reversal undoes the wrong batch item. Both silently discard any quantity they cannot allocate, and a `max(0, ...)` in the stock report hides the evidence.

**Severity: High / Effort: 2d / Safe on live: Yes — it converts silent corruption into a loud failure.**

## Why this matters

### Credit and debit walk the list in opposite directions

`app/Services/WarehouseDocumentService.php`, `creditProductionBatchItems` (lines 264-286):

```php
$batchItems = ProductionBatchItem::where('product_variant_id', $variantId)
    ->whereRaw('(COALESCE(produced_quantity, 0) - COALESCE(warehouse_received_quantity, 0)) > 0')
    ->orderBy('id')              // ← FIFO
    ->lockForUpdate()
    ->get();
```

And `debitProductionBatchItems` (lines 291-312):

```php
$batchItems = ProductionBatchItem::where('product_variant_id', $variantId)
    ->where('warehouse_received_quantity', '>', 0)
    ->orderByDesc('id')          // ← LIFO
    ->lockForUpdate()
    ->get();
```

`orderBy('id')` against `orderByDesc('id')`. The docblocks say so out loud — "FIFO" at line 260, "LIFO" at line 289 — so this was a choice, not a typo. It is still wrong.

Debit exists to **undo** a credit. `reverseMovements` calls it when a warehouse `in` document is reversed (lines 203-205). An operation that undoes another must walk the same order, or it undoes something else.

Concretely. Variant 77 has two batch items awaiting receipt: item **#10** (produced 40) and item **#20** (produced 60).

1. A warehouse `in` document receives 40. Credit walks FIFO: **#10** goes to `warehouse_received_quantity = 40`. #20 stays at 0.
2. The document was a mistake and is reversed. Debit walks LIFO — highest ID with `warehouse_received_quantity > 0`. #20 has 0, so it is filtered out by the `where` at line 298. #10 has 40, so it is debited.

In that two-item case the filter rescues it. Now add a third:

1. Receive 40 → credit FIFO → **#10** = 40.
2. Receive 60 → credit FIFO (#10 is now full, filtered out by line 271) → **#20** = 60.
3. Reverse the **first** document (the 40) → debit LIFO → walks **#20 first** → takes 40 off #20, leaving #20 = 20, #10 = 40.

The 40 that was reversed came off the wrong batch. #10 still reads as fully received when its receipt was cancelled; #20 reads as partially received when its receipt stands. Every per-batch production figure downstream is now wrong, and the totals still balance — which is why nobody notices.

### Both loops throw away the remainder

`creditProductionBatchItems`, lines 276-285:

```php
$remaining = $quantity;
foreach ($batchItems as $batchItem) {
    if ($remaining <= 0) {
        break;
    }
    $receivable = $batchItem->produced_quantity - $batchItem->warehouse_received_quantity;
    $credit     = min($remaining, $receivable);
    $batchItem->increment('warehouse_received_quantity', $credit);
    $remaining -= $credit;
}
```

The loop ends. `$remaining` may be greater than zero. **Nothing happens.** No exception, no log, no return value. The variable goes out of scope and the quantity it held ceases to exist. `debitProductionBatchItems` (lines 303-311) does the same.

The failure: production reports 60 units produced for variant 77. The warehouse receives **100** — a miscount, or a document entered twice, or goods from an unrecorded batch.

- `syncItems` writes a `StockMovement` of `in` 100 (lines 161-169). Warehouse stock: **+100**.
- `creditProductionBatchItems(77, 100)` allocates 60 across the batch items and hits the end of the list with `$remaining = 40`.
- Those **40 units vanish from the production side**. Nothing records that the warehouse accepted 40 units no batch produced.

The database now permanently holds `quantity_warehouse: 100` next to a production side that accounts for 60. The two never reconcile. There is no error to search for and no log line to find, because the discrepancy was never written down — it was subtracted from a local variable and forgotten.

### And the report hides it

`app/Http/Controllers/Api/V1/StockController.php:177`:

```php
'quantity_reserved'  => max(0, (int) $row->qty_received - (int) $row->qty_shipped),
```

`max(0, ...)` clamps the floor. If `qty_shipped` exceeds `qty_received` — which is precisely what happens when receipts went missing, or when step 03's over-shipping bug fired — the report prints **0** instead of the negative number that would reveal it.

A negative reserved quantity is impossible in a consistent database. It is therefore an excellent alarm: it can only appear when something upstream is broken. `max(0, ...)` disables the alarm and leaves the fault burning.

Three bugs, one system: allocation loses track of quantity, the loss surfaces as a negative, and the negative is clamped to zero. Each hides the next.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | What |
|---|---|---|
| `app/Services/WarehouseDocumentService.php` | 264-286 | `creditProductionBatchItems` — throw on remainder. |
| `app/Services/WarehouseDocumentService.php` | 291-312 | `debitProductionBatchItems` — FIFO, throw on remainder. |
| `app/Http/Controllers/Api/V1/StockController.php` | 177 | The `max(0, ...)` mask. |

Both helpers already take `lockForUpdate()` (lines 273 and 300) and both are called from inside a transaction — `syncItems` at line 172, `reverseMovements` at line 204. **Confirm the transaction boundary before relying on it**: check the public methods that call `syncItems` and `reverseMovements` actually wrap them in `DB::transaction`. If they do not, a thrown exception will not roll back the `StockMovement` written at lines 161-169, and you will have converted a silent corruption into a *louder* corruption. Verify first:

```bash
grep -n 'DB::transaction\|syncItems\|reverseMovements' app/Services/WarehouseDocumentService.php
```

## The change

### 1. Make debit FIFO

```php
// current — line 299
->orderByDesc('id')

// intended
->orderBy('id')
```

And fix the docblock at line 289, which currently advertises the bug:

```php
// current
/**
 * LIFO: undo previously credited warehouse_received_quantity (used on reversal).
 */

// intended
/**
 * FIFO: undo previously credited warehouse_received_quantity (used on reversal).
 *
 * Must walk the same order as creditProductionBatchItems, or a reversal
 * debits a different batch item than the one the original credit filled.
 */
```

One line of code. The comment is the more important half — it states *why* the order is not free to change.

**FIFO on `id` is not the same as FIFO on production order.** `id` is insertion order into `production_batch_items`, which correlates with but does not equal the order goods were produced. Both helpers use it consistently, so credit and debit will now agree with each other, which is what this step needs. Whether `id` is the *right* key is a separate question — if batches carry a production date, that is arguably the truer FIFO. Do not change the key here; make the two sides agree first, and raise the key question separately.

### 2. Throw on an unallocated remainder

```php
// intended — end of creditProductionBatchItems, after the loop
if ($remaining > 0) {
    throw new \RuntimeException(sprintf(
        'Cannot allocate %d of %d received units for variant %d: production batch items '
        . 'only account for %d unreceived units. The warehouse is receiving more than '
        . 'production recorded.',
        $remaining, $quantity, $variantId, $quantity - $remaining
    ));
}
```

```php
// intended — end of debitProductionBatchItems, after the loop
if ($remaining > 0) {
    throw new \RuntimeException(sprintf(
        'Cannot debit %d of %d units for variant %d: production batch items only hold '
        . '%d received units. The reversal exceeds what was credited.',
        $remaining, $quantity, $variantId, $quantity - $remaining
    ));
}
```

Inside a transaction this rolls back the whole document — the `StockMovement`, the `WarehouseDocumentItem`, the header. **That is the correct outcome.** A warehouse document that cannot be reconciled against production should not be accepted at all. Accepting the stock movement and dropping the allocation, which is today's behaviour, is the worst of both.

`RuntimeException` surfaces as a 500. Consider `ValidationException::withMessages()` instead so the user gets a 422 naming the variant and the shortfall — the file already imports it (line 16) and `assertSufficientStock` uses it at lines 239-241. A warehouse clerk receiving 100 against a produced 60 has made a *data* error, and a 422 tells them so; a 500 tells them the system is broken. Prefer the 422, but only if you are confident the message reaches the UI — an unhandled 500 that rolls back is still better than a silent accept.

### 3. Unmask the report

```php
// current — StockController.php:177
'quantity_reserved'  => max(0, (int) $row->qty_received - (int) $row->qty_shipped),

// intended
'quantity_reserved'  => (int) $row->qty_received - (int) $row->qty_shipped,
```

The API now returns negative values when the data is inconsistent. **This is the intent** — the number is a symptom and clamping it hid the disease.

But do not ship the raw removal blind. Two things must happen with it:

**Log the anomaly**, so the negatives are findable without someone eyeballing a screen:

```php
$reserved = (int) $row->qty_received - (int) $row->qty_shipped;

if ($reserved < 0) {
    Log::warning('stock.reserved_negative', [
        'variant_id'   => $row->id,
        'qty_received' => (int) $row->qty_received,
        'qty_shipped'  => (int) $row->qty_shipped,
        'reserved'     => $reserved,
    ]);
}

return [
    // ...
    'quantity_reserved' => $reserved,
];
```

Note this logs on every read of the stock list, so a persistent negative will spam. That is arguably correct — it stops being noise when someone fixes it — but if the volume is unworkable, move the check to a scheduled command that reports the set once a day. Do not solve the noise by removing the log.

**Check what the client app does with a negative.** Grep `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_client` for `quantity_reserved`. If the Flutter side parses it into an unsigned type, formats it into a progress bar, or subtracts it from something, a negative may crash the screen or render nonsense. **Find out before deploying.** The API being honest is worthless if it takes the warehouse tablet down. If the client cannot handle it, keep `max(0, ...)` in the *response* for now, add the log, and fix the client first — a logged anomaly with a clamped display is still a large improvement over silence.

## How to verify

No test suite. Staging, restored from a production dump.

**1. Find the damage that already exists.** Run against **production**, before any code change:

```sql
-- Batch items where the warehouse received more than production produced.
-- Every row is an allocation that already went wrong.
SELECT pbi.id, pbi.product_variant_id, pbi.produced_quantity, pbi.warehouse_received_quantity,
       pbi.warehouse_received_quantity - pbi.produced_quantity AS excess
FROM production_batch_items pbi
WHERE pbi.warehouse_received_quantity > pbi.produced_quantity
ORDER BY excess DESC;
```

And the aggregate view — variants where the two sides disagree:

```sql
SELECT pbi.product_variant_id,
       SUM(pbi.produced_quantity)            AS produced,
       SUM(pbi.warehouse_received_quantity)  AS received,
       COALESCE(sm.stock_in, 0)              AS warehouse_in
FROM production_batch_items pbi
LEFT JOIN (
    SELECT product_variant_id,
           SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE 0 END) AS stock_in
    FROM stock_movements GROUP BY product_variant_id
) sm ON sm.product_variant_id = pbi.product_variant_id
GROUP BY pbi.product_variant_id, sm.stock_in
HAVING received <> produced OR warehouse_in <> received;
```

Save both. This is the pre-existing corruption — **the fix does not repair it**, it only stops it growing. Hand the list to whoever owns the physical count.

And the negatives the mask is currently hiding:

```sql
-- Mirror of StockController's qty_received/qty_shipped, unclamped.
-- Read the actual subqueries at StockController.php:101-115 and match them;
-- they scope to active orders, which this simplified query does not.
```

**Read `StockController` lines 100-140 and reproduce its `qtyReceivedForActiveOrders` and `qtyShippedForActiveOrders` subqueries exactly** before trusting any count here. I have not reproduced them in this file because they are built from `selectSub` closures defined above line 120, and quoting them from memory would be a guess. Open the file, read them, write the query to match.

**2. Reproduce the LIFO bug.** On staging, build the three-step scenario:

```sql
-- Find a variant with two or more batch items, both awaiting receipt
SELECT product_variant_id, GROUP_CONCAT(id ORDER BY id) AS batch_item_ids,
       GROUP_CONCAT(produced_quantity ORDER BY id)      AS produced,
       GROUP_CONCAT(warehouse_received_quantity ORDER BY id) AS received
FROM production_batch_items
WHERE COALESCE(produced_quantity, 0) - COALESCE(warehouse_received_quantity, 0) > 0
GROUP BY product_variant_id
HAVING COUNT(*) >= 2;
```

Post an `in` document for the first quantity, note which batch item took the credit, post a second, then reverse the **first** document (`DELETE /api/v1/warehouse-documents/{id}` — confirm the route and method at `routes/api.php:125`).

- **Before the change:** the debit lands on the **higher** batch item ID. Wrong one.
- **After the change:** it lands on the same item the credit filled.

Check after each step:

```sql
SELECT id, produced_quantity, warehouse_received_quantity
FROM production_batch_items WHERE product_variant_id = <v> ORDER BY id;
```

**3. Reproduce the vanishing remainder.** Find a variant with a known unreceived total — say 60 across its batch items. Post an `in` document for **100**:

```bash
curl -X POST https://staging/api/v1/warehouse-documents \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"type": "in", "document_date": "2026-07-14",
       "items": [{"product_color_id": <pc>, "product_size_id": <ps>,
                  "product_edge_id": <e>, "quantity": 100}]}'
```

- **Before the change:** **201**. `warehouse_received_quantity` sums to 60, `stock_movements` has an `in` of 100. Forty units gone, no trace.
- **After the change:** **422** (or 500), and **nothing is written**:

```sql
SELECT MAX(id) FROM warehouse_documents;        -- unchanged
SELECT MAX(id) FROM stock_movements;            -- unchanged
SELECT MAX(id) FROM warehouse_document_items;   -- unchanged
SELECT id, warehouse_received_quantity FROM production_batch_items
WHERE product_variant_id = <v>;                 -- unchanged
```

That last check is the important one: it proves the rollback covers the **partial allocation**. The loop increments batch items one at a time before hitting the remainder — if the transaction is not covering it, some items will have been credited and stayed credited. **If any `warehouse_received_quantity` moved, the transaction boundary is wrong**, and you have made things worse rather than better. Stop and fix that before anything else.

**4. Regression: the valid path.** Post an `in` document for **exactly** the unreceived quantity (60) → **201**, allocation exact, `$remaining` reaches 0. Then a partial (30 of 60) → 201, FIFO fills the lowest ID first. The fix must not reject correct documents.

**5. Reversal within bounds.** Reverse a document whose full quantity was credited → 201, `warehouse_received_quantity` returns to its prior value on the **same** batch items. Compare against a snapshot taken before the original receipt.

**6. The unmasked report.** `GET /api/v1/stock` on a dataset with a known negative (from step 1) → `quantity_reserved` is negative, and `stock.reserved_negative` appears in `storage/logs/laravel.log`.

**7. Drive the client app.** Open the stock screen on staging against data with a negative reserved value. It must render — not crash, not show "NaN", not show a broken bar. This is the check that decides whether step 3 ships unclamped.

## Rollback

Pure code change, no migration. `git revert` and deploy.

The risk on rollout is **the opposite of the usual one**: this change makes previously-accepted documents fail. If production is routinely receiving more than it produces — and the step-1 query will tell you whether it is — then warehouse staff will hit 422s on documents that worked yesterday.

**Run the step-1 queries against production before deploying.** If they return many rows, the mismatch is normal operating procedure, not a rare fault, and throwing will stop the warehouse. In that case: land the **logging** first, without the throw, and watch for a week — the same log-only pattern step 02 uses, and for the same reason. Then decide whether to enforce.

If you ship the throw and it fires in production, revert immediately rather than debugging live. The corruption it prevents has been accruing for months; one more day is cheaper than a stopped goods-in desk.

## Depends on / blocks

- **Depends on:** nothing strictly. Best **after step 04**, since that step fixes `WarehouseDocumentService` resolving the wrong variant entirely — allocating correctly to the wrong variant's batch items is not progress. Land 04 first.
- **Blocks:** nothing in phase 1.
- **Related to step 03.** Negative `quantity_reserved` has two possible causes: receipts that went missing (this step) or shipments that over-shipped (step 03). With both landed, a negative means something new is wrong. With neither, it means nothing in particular. They are most useful together.
- **Phase-2:** the `production_events` work replaces this allocation entirely with an append-only event log, where "the remainder was discarded" is not expressible. This step is the interim guard — keep it small.
