# Stop batch edits from wiping production history

`ProductionBatchService::update()` deletes and re-creates every item, resetting `produced_quantity` to 0 and orphaning printed QR labels.

**Severity:** Critical · **Effort:** 2 h · **Safe on live:** Yes — this only *rejects* requests that currently destroy data

**Finding:** PROD-1 · **Superseded by:** `phase-2/01` — this is a guard, not the fix

## Why this matters

`app/Services/ProductionBatchService.php:86`:

```php
if (isset($data['items'])) {
    // Remove old items and re-sync
    $batch->items()->delete();
    $this->syncItems($batch, $data['items']);
    $this->syncOrderStatuses($batch);
}
```

`syncItems()` (line 224) creates rows with only `source_type`, `source_order_item_id`, `product_variant_id`, `planned_quantity` and `notes`. It never carries over `produced_quantity`, `defect_quantity` or `warehouse_received_quantity` — they default to 0. And the new rows get **new IDs**.

### Failure scenario

A batch is 80% woven — `produced_quantity` = 400 of 500. Someone fixes a typo in one line's planned quantity and PATCHes the batch.

1. All 500 units of recorded production **vanish**: `produced_quantity = 0`, `defect_quantity = 0`, `warehouse_received_quantity = 0`.
2. Every QR label already printed and glued to a carpet encodes `PB{batchId} PBI{oldItemId}` (see `ProductionBatchController::scanItem`, the regex at line ~322). Those item IDs no longer exist → **scanning any of those carpets returns 404 forever**. The labels are physically on the goods and cannot be recalled.
3. `warehouse_document_items.source_id` still points at the deleted IDs. It is polymorphic with **no foreign key** (`2026_04_13_000002` — "not enforced by DB due to polymorphism, but enforced at the service layer", which it is not), so the database allows it and the pointers silently dangle.
4. If any defect document exists for the batch, `defect_document_items.production_batch_item_id` **is** a real FK with RESTRICT (`2026_04_12_000002` uses bare `->constrained()`), so the delete throws a raw SQL error → **HTTP 500**, transaction rolls back, and the user sees a crash instead of an explanation.

So the outcome depends on whether a defect document happens to exist: either a 500, or silent destruction of the batch's entire production record.

## The change

`app/Services/ProductionBatchService.php` — `update()`. Refuse to touch items on a batch that has recorded production:

```php
if (isset($data['items'])) {
    $hasProduction = $batch->items()
        ->where(function ($q) {
            $q->where('produced_quantity', '>', 0)
              ->orWhere('defect_quantity', '>', 0)
              ->orWhere('warehouse_received_quantity', '>', 0);
        })
        ->exists();

    if ($hasProduction) {
        throw ValidationException::withMessages([
            'items' => 'Ishlab chiqarish boshlangan partiya mahsulotlarini o\'zgartirib bo\'lmaydi.',
        ]);
    }

    $batch->items()->delete();
    $this->syncItems($batch, $data['items']);
    $this->syncOrderStatuses($batch);
}
```

Match the Uzbek message style used in `StoreDefectDocumentRequest::messages()`. Returning 422 from a `ValidationException` is the right shape here — the controller already returns JSON, and Laravel renders it as 422 automatically.

Header-only edits (`batch_title`, `notes`, `machine_id`, `planned_datetime`) must keep working — the guard is inside the `isset($data['items'])` branch, so they do.

### Also guard `delete()`

`ProductionBatchService::delete()` (line 214) has the same `$batch->items()->delete()` call. The controller gates it on `status === STATUS_PLANNED`, which today is **unreachable** (`create()` hard-codes `in_progress` — see LOGIC-4 / `phase-3/03`), so it is currently dead code. Add the same production check anyway — the moment `phase-3/03` makes `planned` reachable, this path opens up.

### Why not preserve the counters instead?

You could match old items to new ones and carry the counters across. Don't — matching on what? `product_variant_id` isn't unique within a batch, and the client may be renumbering lines. Any matching heuristic silently reattributes real production to the wrong line, which is worse than refusing. `phase-2/01` solves this properly: once production lives in an append-only event log keyed to an item, the item can't be casually deleted, and the guard becomes a foreign key rather than an `if`.

## How to verify

On staging:

1. Create a batch, print a label (`POST .../items/{item}/print-label`) so `produced_quantity = 1`.
2. `PATCH /production-batches/{id}` with an `items` array → expect **422** with the message, and confirm `produced_quantity` is still 1:
   ```sql
   SELECT id, planned_quantity, produced_quantity FROM production_batch_items WHERE production_batch_id = X;
   ```
3. `PATCH` the same batch with only `{"batch_title":"new title"}` → expect **200**. Header edits must not be blocked.
4. Create a fresh batch with no production, `PATCH` its `items` → expect **200**, items replaced. Editing a not-yet-started batch is legitimate and must keep working.
5. Confirm item IDs did not change in case 2:
   ```sql
   SELECT id FROM production_batch_items WHERE production_batch_id = X ORDER BY id;
   ```

## Rollback

Revert the commit. The endpoint returns to destroying history.

## Damage already done

You cannot recover wiped counters — the data never existed anywhere else. But you can find the wreckage:

```sql
-- warehouse_document_items pointing at production_batch_items that no longer exist
SELECT wdi.id, wdi.source_id, wdi.warehouse_document_id
FROM warehouse_document_items wdi
LEFT JOIN production_batch_items pbi ON pbi.id = wdi.source_id
WHERE wdi.source_type = 'production_batch_item'
  AND wdi.source_id IS NOT NULL
  AND pbi.id IS NULL;
```

Every row is an orphaned pointer from a batch edit. If that query returns anything, this bug has already fired in production, and the corresponding carpets carry QR labels that scan to nothing. Report the count to the owner.
