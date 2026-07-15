# Decrement `defect_quantity` when a defect document is deleted

`store()` increments the counter; `destroy()` deletes the evidence but leaves the number inflated forever.

**Severity:** High · **Effort:** 1 h · **Safe on live:** Yes

**Finding:** PROD-2 · **Superseded by:** `phase-2/05` — this is the interim guard, not the real fix

## Why this matters

`app/Http/Controllers/Api/V1/DefectDocumentController.php:56` increments on create:

```php
ProductionBatchItem::where('id', $itemData['production_batch_item_id'])
    ->increment('defect_quantity', $itemData['quantity']);
```

`destroy()` at line 94 does not decrement:

```php
DB::transaction(function () use ($defectDocument): void {
    foreach ($defectDocument->photos as $photo) {
        Storage::disk('public')->delete($photo->path);
    }
    $defectDocument->delete();      // cascade-deletes defect_document_items
});
```

`DefectDocument` has no `SoftDeletes`, and `database/migrations/2026_04_12_000002_create_defect_document_items_table.php` declares `->constrained('defect_documents')->cascadeOnDelete()`. So the `defect_document_items` rows are physically removed while `production_batch_items.defect_quantity` keeps the credit. The route is live at `routes/api.php:187`.

### Failure scenario

Batch item, `planned_quantity = 100`. A defect document for 20 is filed by mistake, then deleted.

1. `defect_quantity` = **20**, stuck forever. `DefectDocumentItem::sum()` = **0**. The two sources of truth now disagree.
2. `ProductionBatchService.php:173` auto-completes on `whereRaw('produced_quantity < (planned_quantity - defect_quantity)')`. At `produced = 80`: `80 < (100 - 20)` is **false** → **the batch auto-completes at 80 units**. The last 20 carpets are never woven, and nobody is told.
3. `OrderItemResource.php:44` reports **20 phantom defects** against the order.
4. `StoreDefectDocumentRequest.php:51` computes remaining capacity from `DefectDocumentItem::sum()` (= 0), so it will accept **20 more** → `defect_quantity` = **40** on a 100-unit item → `produced + defect = 120 > planned`.

## The change

`app/Http/Controllers/Api/V1/DefectDocumentController.php` — `destroy()`. Decrement inside the existing transaction, **before** the delete cascades the items away:

```php
DB::transaction(function () use ($defectDocument): void {
    // Must run before delete() — the cascade removes the items we need to read.
    $defectDocument->loadMissing('items');

    foreach ($defectDocument->items as $item) {
        ProductionBatchItem::where('id', $item->production_batch_item_id)
            ->decrement('defect_quantity', $item->quantity);
    }

    foreach ($defectDocument->photos as $photo) {
        Storage::disk('public')->delete($photo->path);
    }

    $defectDocument->delete();
});
```

Note `ProductionBatchService::delete()` already uses this same "read before the cascade" ordering, with a comment explaining why — follow that precedent.

### Guard against going negative

`defect_quantity` is `unsignedInteger` (`2026_04_11_000003`). If it has already drifted, decrementing could underflow and throw. Clamp:

```php
ProductionBatchItem::where('id', $item->production_batch_item_id)
    ->where('defect_quantity', '>=', $item->quantity)
    ->decrement('defect_quantity', $item->quantity);
```

That silently skips already-drifted rows rather than 500ing. Log when the guard fires — a skipped decrement means existing corruption, and you want to know:

```php
Log::warning('defect_quantity decrement skipped — counter already below document quantity', [
    'production_batch_item_id' => $item->production_batch_item_id,
    'document_id' => $defectDocument->id,
    'quantity' => $item->quantity,
]);
```

### Should the batch re-open?

If deleting a defect document means the batch is no longer complete, arguably `checkAndCompleteProductionBatch` should run in reverse. **Don't do that here.** Reverting a `completed` batch to `in_progress` is a workflow decision with consequences downstream (warehouse receipts, order status), and this step is a counter fix. Note it for `phase-3/03`, which deals with the state machine.

## Why this is only the interim fix

You are still maintaining a counter by hand in two places that can drift. `phase-2/05` replaces this with an append-only correction event, at which point deletion appends a reversing row instead of mutating a number, and the counter becomes derived. This step just stops the bleeding until then.

## How to verify

No test suite. On staging:

1. Note `defect_quantity` for a batch item: `SELECT id, planned_quantity, produced_quantity, defect_quantity FROM production_batch_items WHERE id = X;`
2. `POST /production-batches/{batch}/defect-documents` with qty 20 → confirm `defect_quantity` rose by 20.
3. `DELETE /defect-documents/{id}` → confirm `defect_quantity` returned to its original value.
4. Confirm `SELECT COUNT(*) FROM defect_document_items WHERE defect_document_id = <id>;` is 0 (cascade worked).
5. **The reconciliation invariant** — after any number of create/delete cycles, these must match for every item:
   ```sql
   SELECT pbi.id,
          pbi.defect_quantity,
          COALESCE(SUM(ddi.quantity), 0) AS from_documents
   FROM production_batch_items pbi
   LEFT JOIN defect_document_items ddi ON ddi.production_batch_item_id = pbi.id
   GROUP BY pbi.id, pbi.defect_quantity
   HAVING pbi.defect_quantity <> from_documents;
   ```
6. Repeat with a batch item that has multiple defect documents; delete the middle one.

## Rollback

Revert the commit. No data written by the fixed code needs undoing — decrements are correct.

## Measure the existing damage first

Run query 5 above **read-only against production before deploying**. Every row it returns is a batch item already corrupted by this bug. Some will have auto-completed early, meaning carpets that were ordered were never woven. Give the owner that list — it may explain short deliveries nobody could account for.
