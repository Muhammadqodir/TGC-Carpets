# 05 — Signed adjustment documents (LOGIC-6)

Adjustments can only ever add stock, so the most common stocktake result — fewer carpets than recorded — cannot be entered at all.

**Severity: High / Effort: 3 days / Safe on live: No — changes stock movement semantics; small change, large blast radius**

## Why this matters

A migration collapsed four movement types into two and left a note admitting the problem. `tgc_backend/database/migrations/2026_04_30_000001_simplify_stock_movements_type.php` lines 24–37:

```php
// Convert existing 'adjustment' movements to 'in'
// Note: If adjustments should sometimes be 'out', this needs manual review
DB::statement("
    UPDATE stock_movements
    SET movement_type = 'in'
    WHERE movement_type = 'adjustment'
");

// Now alter the column to ENUM with only 'in' and 'out'
DB::statement("
    ALTER TABLE stock_movements
    MODIFY COLUMN movement_type
        ENUM('in','out') NOT NULL
");
```

"If adjustments should sometimes be 'out', this needs manual review." They should, and this is that review.

The service layer hardcodes the same assumption. `tgc_backend/app/Services/WarehouseDocumentService.php` `syncItems()` lines 149–159:

```php
// Map warehouse document types to stock movement types
// 'in' → 'in' (stock coming into warehouse)
// 'out' → 'out' (stock leaving warehouse)
// 'return' → 'in' (returned items add back to stock)
// 'adjustment' → 'in' (inventory corrections typically add stock)
$movementType = match ($document->type) {
    WarehouseDocument::TYPE_IN,
    WarehouseDocument::TYPE_RETURN,
    WarehouseDocument::TYPE_ADJUSTMENT => StockMovement::TYPE_IN,
    WarehouseDocument::TYPE_OUT        => StockMovement::TYPE_OUT,
};
```

"Inventory corrections typically add stock" is false. Corrections typically *reduce* stock — that is what shrinkage, miscounts, damage and theft look like. The common case is the one that cannot be entered.

**There is a second copy of this match** that the original brief did not mention. `reverseMovements()` lines 177–190:

```php
$originalMovementType = match ($document->type) {
    WarehouseDocument::TYPE_IN,
    WarehouseDocument::TYPE_RETURN,
    WarehouseDocument::TYPE_ADJUSTMENT => StockMovement::TYPE_IN,
    WarehouseDocument::TYPE_OUT        => StockMovement::TYPE_OUT,
};
```

Both must change together, or reversing an adjustment will write a movement in the wrong direction and silently corrupt the ledger — worse than the bug being fixed. This is the main hazard in this file.

### Consequence 1: the common stocktake cannot be entered

The warehouse counts 480 carpets of a variant. The system says 500. The correct entry is an adjustment of −20. There is no way to express it:

- an `adjustment` document for 20 → **adds** 20, making it 520. Exactly backwards, and off by 40.
- an `out` document for 20 → arithmetically right, but now the ledger says 20 carpets were shipped out of the warehouse, which is a lie. `isOutgoing()` is true, it appears in outbound reporting, and the reason for the loss is destroyed.

So the choice is a wrong number or a wrong story. In practice people will pick `out`, and the shrinkage becomes invisible — you lose the ability to measure the thing the adjustment existed to measure.

### Consequence 2: adjustment mints stock from nothing

`WarehouseDocumentService::create()` (line 28), lines 37–40:

```php
return DB::transaction(function () use ($data, $userId): WarehouseDocument {
    if ($data['type'] === WarehouseDocument::TYPE_OUT) {
        $this->assertSufficientStock($data['items']);
    }
```

Only `TYPE_OUT` is stock-checked. `adjustment` maps to `in`, so it is never validated against anything and always increases stock. Anyone who can create a warehouse document can add 10,000 carpets to any variant with no order, no production batch, no counterparty and no check. Combined with `EnsureRole` being applied to zero routes (see `06-audit-log.md`), that is currently *any authenticated user*.

This is not theoretical: it is the easiest way to make the numbers "look right" when they do not, which means it is how the ledger will get corrupted.

### Consequence 3: two definitions of "incoming" in one domain

`tgc_backend/app/Models/WarehouseDocument.php` lines 57–65:

```php
public function isIncoming(): bool
{
    return in_array($this->type, [self::TYPE_IN, self::TYPE_RETURN], true);
}

public function isOutgoing(): bool
{
    return $this->type === self::TYPE_OUT;
}
```

`isIncoming()` **excludes** adjustment. The `match` in the service **treats it as incoming**. So an adjustment document is:
- incoming, according to `syncItems()` — it writes a `TYPE_IN` movement
- neither incoming nor outgoing, according to the model — both helpers return false

Two definitions of the same word, in the same domain, one file apart. Any caller that branches on `isIncoming()` / `isOutgoing()` silently skips adjustments entirely. Find them before changing anything:

```bash
cd tgc_backend && grep -rn "isIncoming\|isOutgoing" app/ resources/ routes/
```

## Files to change

- `tgc_backend/app/Services/WarehouseDocumentService.php` — `create()` line 28 (stock check lines 37–40), `syncItems()` line 133 (match lines 154–159), `reverseMovements()` line 177 (match lines 180–185)
- `tgc_backend/app/Models/WarehouseDocument.php` — `isIncoming()` line 57, `isOutgoing()` line 62, type constants lines 15–25
- `tgc_backend/app/Http/Requests/WarehouseDocument/StoreWarehouseDocumentRequest.php`
- `tgc_backend/app/Http/Requests/WarehouseDocument/UpdateWarehouseDocumentRequest.php` — note this file is currently missing the `items.*.product_color_id` rule (Phase 0 bug); confirm that is fixed before touching it
- new migration for the direction column
- `tgc_backend/resources/views/pdf/warehouse_document.blade.php` — must show the sign
- client: warehouse document create/edit forms

## The change

Give the adjustment a direction. Two options; pick the first.

### Option A — a `direction` column on the document (recommended)

```sql
ALTER TABLE warehouse_documents
  ADD COLUMN direction ENUM('in','out') NULL DEFAULT NULL AFTER type;

-- every existing adjustment behaved as 'in'; record that truthfully
UPDATE warehouse_documents SET direction = 'in' WHERE type = 'adjustment';
```

`NULL` for non-adjustment types, where direction is implied by `type`. Non-null and meaningful only for `adjustment`. Then:

```php
$movementType = match ($document->type) {
    WarehouseDocument::TYPE_IN,
    WarehouseDocument::TYPE_RETURN     => StockMovement::TYPE_IN,
    WarehouseDocument::TYPE_OUT        => StockMovement::TYPE_OUT,
    WarehouseDocument::TYPE_ADJUSTMENT => $document->direction === 'out'
        ? StockMovement::TYPE_OUT
        : StockMovement::TYPE_IN,
};
```

**Extract this into one method** — `WarehouseDocument::movementType()` — and call it from both `syncItems()` and `reverseMovements()`. The duplicated match is the bug generator here; do not fix it twice, delete one of them. `reverseMovements()` then keeps its existing invert logic (lines 187–190) unchanged and works correctly for both directions for free.

The backfill is exact: every historical adjustment did add stock, so `direction = 'in'` records what actually happened rather than guessing. No historical balance moves. That is what makes this safe.

Make `direction` required when `type = 'adjustment'`:

```php
'direction' => [
    Rule::requiredIf(fn () => $this->input('type') === WarehouseDocument::TYPE_ADJUSTMENT),
    'nullable',
    Rule::in(['in', 'out']),
],
```

### Option B — a signed quantity on the item

Let `warehouse_document_items.quantity` go negative for adjustments and derive the movement type from the sign.

Rejected, but know why: `quantity` is `unsignedInteger` in the current schema, so this needs a column type change on a hot table; every existing `SUM(quantity)` in the codebase silently changes meaning; and negative quantities will leak into PDFs and client displays that assume positive. It also does not fix the `isIncoming()` split. Option A confines the change to a nullable column that old code ignores.

If Phase 2's `production_events` uses a signed quantity, note the inconsistency and live with it — the event ledger is append-only and internal, while `warehouse_document_items` is rendered on documents people hold in their hands.

### Fix the stock check

The unguarded-minting hole is arguably more urgent than the direction itself. `create()` lines 37–40:

```php
// current
if ($data['type'] === WarehouseDocument::TYPE_OUT) {
    $this->assertSufficientStock($data['items']);
}

// intended
if ($this->reducesStock($data)) {
    $this->assertSufficientStock($data['items']);
}
```

where `reducesStock()` is true for `TYPE_OUT` and for `TYPE_ADJUSTMENT` with `direction = 'out'`. A negative adjustment must not be able to drive a variant's balance below zero any more than a shipment can.

An adjustment that *adds* stock stays unchecked by arithmetic — there is nothing to check — but it must not stay unguarded. Require:
- a mandatory free-text `reason` on every adjustment document (`notes` exists but is nullable; adjustments should demand it)
- role restriction to warehouse managers once `EnsureRole` is actually applied to routes (Phase 1)
- an audit entry (`06-audit-log.md`)

### Fix the two definitions of "incoming"

```php
public function isIncoming(): bool
{
    return $this->movementType() === StockMovement::TYPE_IN;
}

public function isOutgoing(): bool
{
    return $this->movementType() === StockMovement::TYPE_OUT;
}
```

Now there is one definition, both helpers cover all four types, and they cannot disagree with `syncItems()` because they are the same code. **Check every caller first** — a caller relying on `isIncoming()` returning false for adjustments will change behaviour. That grep is the first thing to run in this task.

### Documents must show the sign

`resources/views/pdf/warehouse_document.blade.php` prints quantities and a `Jami dona` total (line 369). A −20 adjustment that prints as `20` is a document that says the opposite of what happened. Print the direction in the header and the sign on the total. This matters more than it sounds: the PDF is the artefact the warehouse keeps.

## How to verify

1. Backfill: every existing adjustment has `direction = 'in'`. `SELECT type, direction, COUNT(*) FROM warehouse_documents GROUP BY 1,2` — no adjustment with a null direction.
2. **Total net stock per variant is identical before and after the migration.** Snapshot `SELECT product_variant_id, SUM(CASE WHEN movement_type='in' THEN quantity ELSE -quantity END) FROM stock_movements GROUP BY 1` before and after, and diff. It must be byte-identical. If a single variant moves, stop.
3. Create an adjustment `direction = 'out'`, quantity 20, on a variant with 500 → balance 480. This is the case that was impossible.
4. Create an adjustment `direction = 'in'`, quantity 20 → balance 520. Old behaviour intact.
5. **Reverse/delete the `out` adjustment → balance returns to 500.** This is the test that catches a half-updated `reverseMovements()`. Do the same for the `in` adjustment. Both must round-trip to zero.
6. Adjustment `direction = 'out'`, quantity 999999 on a variant with 500 → rejected by the stock check, not accepted into the negative.
7. Adjustment with no `direction` → 422.
8. Adjustment with no reason → 422.
9. `isIncoming()` / `isOutgoing()` return correct values for all four types plus both adjustment directions. Assert every callsite found by the grep still behaves.
10. The PDF for an `out` adjustment visibly shows it as a reduction.
11. An **old client** creating an adjustment with no `direction` field: decide the behaviour deliberately. Defaulting to `in` preserves current behaviour and keeps the deploy safe; 422 is correct but breaks the client until it ships. Recommend defaulting to `in` server-side for one release, then making it required.

## Rollback

The `direction` column is additive and nullable; old code ignores it and treats every adjustment as `in`. So a code-only revert is safe **as long as no `direction = 'out'` adjustment exists**. Once one does, reverting means the old code reads that document as incoming and any recomputation flips 20 carpets the wrong way — a 40-unit error per document.

Before reverting, find them:

```sql
SELECT id, document_date FROM warehouse_documents WHERE type = 'adjustment' AND direction = 'out';
```

Reverse those documents through the application first, then revert the code, then re-enter them however the old system allowed. Given the window, ship this on a day the warehouse is quiet and watch for a week before considering it settled.

The `stock_movements` rows themselves are never rewritten by this change — only the direction of *new* movements. That is deliberate: the ledger stays append-only and the migration touches no history.

## Depends on / blocks

- **Depends on `01-tests-and-ci.md`.** The stock ledger suite is specified to cover every document type, its reversal, and the return-to-zero assertion. That suite is exactly the safety net for this change, and file 01 notes the adjustment case will fail against current behaviour — this file is that failure's fix. Write the test first, watch it fail, then fix.
- **Depends on Phase 0** — `UpdateWarehouseDocumentRequest` is missing `items.*.product_color_id`, so document editing is 100% broken. Fix that before adding validation rules to the same file.
- **Interacts with Phase 1** (`EnsureRole` applied to routes). The role restriction on adjustments needs that work; ship the direction fix without it, then tighten.
- **Interacts with Phase 2.** If `production_events` has landed with a signed quantity, this brings warehouse documents into line conceptually — but note the two use different mechanisms (direction column vs signed quantity) for good reasons. Document that.
- **Blocks `07-stock-reservations.md`** in spirit: reserving stock against a balance that cannot be corrected downward means reservations inherit the error. Not a hard gate.
- **Blocks nothing else.** Three days, self-contained, high value. Do it early — right after `01`.
