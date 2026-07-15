# Fix `reverseMovements()` — deleting a document can *add* stock

The reversal direction is read from a mutable column that `update()` has already changed, instead of from the ledger rows being reversed.

**Severity:** Critical · **Effort:** 2 h · **Safe on live:** Yes — pure bug fix

**Finding:** LOGIC-1 · **Blocks:** `phase-0/04` — fix this **first** · **Depends on:** nothing

## Why this matters

`app/Services/WarehouseDocumentService.php:177` decides what to reverse by reading `$document->type`:

```php
private function reverseMovements(WarehouseDocument $document, int $userId): void
{
    // Determine the original movement type that was created
    $originalMovementType = match ($document->type) {        // ← line 180
        WarehouseDocument::TYPE_IN,
        WarehouseDocument::TYPE_RETURN,
        WarehouseDocument::TYPE_ADJUSTMENT => StockMovement::TYPE_IN,
        WarehouseDocument::TYPE_OUT        => StockMovement::TYPE_OUT,
    };
```

But `update()` at line 66 already wrote the new type before calling it:

```php
$document->update(array_filter([
    'type' => $data['type'] ?? $document->type,        // ← line 68, persisted AND mutates in memory
    ...
]));

if (! empty($data['items'])) {
    $effectiveType = $document->fresh()->type;         // ← line 74, computed…
    ...
    $this->reverseMovements($document, $userId);       // ← line 80, …and never passed down
```

`$effectiveType` exists, is correct, and is used only for the stock check at line 76. `reverseMovements()` re-reads the mutated attribute.

**The conceptual error:** the direction of a reversal is a property of *the rows already in the ledger*, not of a column someone can edit afterwards.

### Failure scenario — permanent phantom stock

1. `POST /warehouse-documents` — `type: "in"`, qty **100** → ledger gets `in +100`. Stock = **100**.
2. `PATCH /warehouse-documents/42` with `{"type":"out"}` and **no `items`** → line 73's `if (! empty($data['items']))` is false, so the ledger is never touched. The document now says `out`; the ledger still says `in`. (That's `phase-0/03`.)
3. `DELETE /warehouse-documents/42` → `delete()` (line 100) → `reverseMovements()` → `match` sees `out` → decides the original was `out` → writes the reverse of `out`, i.e. **another `in +100`**.

Stock = **200** for a document that no longer exists. Expected **0**. Drift: **+200 units**, silent, permanent, no error surfaced.

The `debitProductionBatchItems` call at line 203 is gated on the same mutated type, so it is skipped too — `warehouse_received_quantity` keeps its original credit as well.

## Files to change

- `app/Services/WarehouseDocumentService.php` — `reverseMovements()` (line 177), and the gate at line 203

## The change

Derive the reversal from the ledger. `app/Models/WarehouseDocumentItem.php:55` already has the relation you need:

```php
public function stockMovements(): HasMany
{
    return $this->hasMany(StockMovement::class);
}
```

**Use the net-sum approach, not a row-per-row mirror.** Summing the item's existing movements to a net figure and writing one compensating movement is naturally idempotent: if a reversal has already been written, the net is already 0 and the second call writes nothing. A row-per-row mirror would happily reverse its own reversals.

Sketch — adapt to the codebase's style:

```php
private function reverseMovements(WarehouseDocument $document, int $userId): void
{
    foreach ($document->items as $item) {
        // Net of everything already in the ledger for this item: +in, -out.
        $net = (int) $item->stockMovements()
            ->selectRaw("COALESCE(SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END), 0) as net")
            ->value('net');

        if ($net === 0) {
            continue;   // nothing to reverse, or already reversed
        }

        StockMovement::create([
            'product_variant_id'         => $item->product_variant_id,
            'warehouse_document_item_id' => $item->id,
            'user_id'                    => $userId,
            'movement_type'              => $net > 0 ? StockMovement::TYPE_OUT : StockMovement::TYPE_IN,
            'quantity'                   => abs($net),
            'movement_date'              => $document->document_date,   // NOT now() — see below
            'notes'                      => "Reversal of document #{$document->id}",
        ]);

        // Gate on what the ledger actually did, not on the document's current type.
        if ($net > 0) {
            $this->debitProductionBatchItems($item->product_variant_id, abs($net));
        }
    }
}
```

Two details worth keeping:

- **`movement_date` should be `document_date`, not `now()`.** The current code stamps `now()` (line 199), so any date-ranged stock report misattributes reversals to the day someone pressed delete. Since you are rewriting the line anyway, fix it here.
- **Do not "fix" the `$effectiveType` variable at line 74** by passing it down. That perpetuates the same mistake — it is still a document column, not the ledger. Delete it once the stock check no longer needs it, or leave it for `phase-0/03` to deal with.

## How to verify

No test suite. Verify against a **staging copy of the production database**, never live:

1. Create an `in` document for a variant with known stock. Note `SELECT SUM(...) FROM stock_movements WHERE product_variant_id = X`.
2. Delete it. The sum must return to its starting value.
3. Repeat for `out`, `return`, `adjustment`.
4. **The regression case:** create `in` qty 100 → `PATCH {"type":"out"}` → `DELETE`. Stock must end at the starting value, not starting + 200.
5. Check the ledger by hand:
   ```sql
   SELECT id, movement_type, quantity, movement_date, notes
   FROM stock_movements
   WHERE warehouse_document_item_id IN (...)
   ORDER BY id;
   ```
   You should see the original and exactly one compensating row of opposite type and equal quantity.
6. Call `reverseMovements` twice (delete a document twice via a tinker script) and confirm the second call writes nothing.

## Rollback

Revert the commit. Reversal rows already written by the fixed code are correct and should be kept — they are ordinary ledger entries.

## Before you ship: measure the damage

This bug has very likely already inflated live stock. Before deploying, run **read-only** against production to find variants whose ledger disagrees with reality:

```sql
-- Documents whose items have a non-zero net despite the document being deleted
-- (orphaned reversals — see STRUCT-5, warehouse_document_item_id nulls out on delete)
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END) AS net
FROM stock_movements
WHERE warehouse_document_item_id IS NULL
GROUP BY product_variant_id
HAVING net <> 0;
```

Record the numbers. Fixing the code stops new damage; it does not repair what is already there. Repairing it is a separate, deliberate correction with the owner's sign-off — do not silently adjust stock.
