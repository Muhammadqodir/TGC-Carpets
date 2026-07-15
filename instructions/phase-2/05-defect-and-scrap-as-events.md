# 05 — Defect and scrap as events (PROD-4 + PROD-2)

A finished carpet can never be marked defective, and deleting a defect document inflates `defect_quantity` forever. Fix both by modelling defects as events.

**Severity:** High — one bug blocks real work daily, the other silently corrupts data / **Effort:** 3 days / **Safe on live:** Mostly — the validation change is safe, the delete fix needs a data repair

## Why this matters

### PROD-4: you cannot mark a finished carpet defective

`StoreDefectDocumentRequest::withValidator()` computes the allowance like this (line 48):

```php
$produced  = (int) ($batchItem->produced_quantity ?? 0);
$available = max(0, $batchItem->planned_quantity - $produced);
```

then subtracts defects already recorded (lines 51–54):

```php
$alreadyDefected = (int) DefectDocumentItem::where('production_batch_item_id', $batchItemId)->sum('quantity');
$remaining = max(0, $available - $alreadyDefected);
```

Read line 48 again: **defects can only be taken out of the quantity that has not been produced yet.** Once every label is printed, `produced == planned`, so `available = 0`, so `remaining = 0`, so **every defect document is rejected** with:

> Nuxson miqdori (1) ruxsat etilgan chegaradan (0) oshib ketdi. Reja: 500, Tayor: 500, Avvalgi nuxson: 0.

Concrete: a batch of 500 is fully woven and labelled. QC inspects the finished pile and finds 3 with a weaving fault. The operator cannot record them. Not "it is awkward" — the API returns 422 and there is no path forward in the app. The defect is real, the carpets are real, and the system's position is that they cannot exist.

Which is backwards. A defect is *discovered by inspecting a finished carpet*. The current rule only permits defects on carpets that were never made.

What the floor does instead: nothing, or they log it against some other batch that still has headroom, which is worse than nothing because it is wrong data that looks right.

The underlying confusion is a category error. `produced_quantity` means *good units* (`ProductionBatchController` line 44 confirms: *"produced_quantity is already net good units (excludes defects)"*), and `incrementProducedQuantity` treats `planned = produced + defect` as the completion condition (line 173: `produced_quantity < (planned_quantity - defect_quantity)`). So the invariant is:

```
produced_quantity + defect_quantity <= planned_quantity      (produced = GOOD units)
```

Condemning an already-produced carpet must therefore move a unit **from good to defective** — `produced −1`, `defect +1` — leaving the sum unchanged. The current validator instead assumes defects only ever come out of thin air (the unproduced remainder), which is why it collapses to zero.

### PROD-2: deleting a defect document inflates the counter forever

`DefectDocumentController::destroy()` (line 94):

```php
DB::transaction(function () use ($defectDocument): void {
    foreach ($defectDocument->photos as $photo) {
        Storage::disk('public')->delete($photo->path);
    }
    $defectDocument->delete();
});
```

`store()` incremented `defect_quantity` (lines 56–57). `destroy()` **never decrements it.** The `defect_document_items` rows vanish via `cascadeOnDelete` (verified in `2026_04_12_000002_create_defect_document_items_table.php`), and `DefectDocument` has **no `SoftDeletes`** — the evidence is gone for good.

So after deleting a 5-unit defect document:

| | before delete | after delete |
|---|---|---|
| `defect_quantity` | 5 | **5** ← never decremented |
| `SUM(defect_document_items.quantity)` | 5 | **0** ← cascade-deleted |

The counter is now permanently inflated with no document behind it, and the two numbers can never be reconciled because one side's evidence no longer exists. Worse, it is self-reinforcing: `$alreadyDefected` (line 51) now reads 0, so `remaining` goes *up*, letting someone record the same defects again — inflating `defect_quantity` to 10 for 5 physical carpets.

And it corrupts batch completion. `incrementProducedQuantity` line 173 checks `produced_quantity < (planned_quantity - defect_quantity)`. With `defect_quantity` phantom-inflated by 5, a batch of 500 auto-completes at 495 labels. Five carpets that were ordered are never woven, and nothing reports it.

## Files to change

| File | Line | What is there now |
|---|---|---|
| `tgc_backend/app/Http/Requests/Production/StoreDefectDocumentRequest.php` | 48 | `$available = max(0, $batchItem->planned_quantity - $produced);` |
| ″ | 51–54 | `$alreadyDefected` / `$remaining` |
| `tgc_backend/app/Http/Controllers/Api/V1/DefectDocumentController.php` | 94–106 | `destroy()` — no decrement, no reversing event |
| ″ | 37–79 | `store()` — event write added in step 01 |
| ″ | 111–135 | `checkAndCompleteProductionBatch()` |
| `tgc_backend/app/Services/DefectDocumentService.php` | new | extract the logic out of the controller |

## The change

### 1. The model: what a defect is, and what a scrap is

Two distinct physical events, deliberately kept separate:

| Situation | Meaning | Events written (one transaction) | Net effect |
|---|---|---|---|
| **Defect on unproduced remainder** | carpet came off the loom faulty; never labelled, never counted as good | `('defect', +n)` | `defect +n` |
| **Scrap of a produced unit** | a labelled, counted-good carpet is condemned | `('scrap', −n)` **and** `('defect', +n)` | `produced −n`, `defect +n` |

This is the "negative produced + positive defect" shape, written as **two rows** because `produced_quantity` and `defect_quantity` are two different caches and — per step 01's mapping — each event type feeds exactly one of them. One row cannot move two counters without making reconcile ambiguous. Two rows keep it a plain `GROUP BY`.

**Deliberate deviation, flagged:** reversing a deleted defect document is a **negative `defect` row**, *not* a `correction` row. `correction` is reserved for `produced_quantity` in step 01's mapping; using it for a defect reversal would make both sums ambiguous and defeat the point. A negative `defect` row is still a reversing entry — append-only holds, nothing is mutated.

**Boundary — scrap only applies to units not yet in the warehouse.** Require:

```
produced_quantity - warehouse_received_quantity >= scrap_qty
```

Rationale: once `WarehouseDocumentService::creditProductionBatchItems()` (line 283) has credited a unit, the carpet is warehouse stock. Condemning it there is a stock write-off (a warehouse document), not a production correction. Without this guard, `produced_quantity` can fall below `warehouse_received_quantity` and the `(produced - warehouse_received) > 0` filters at `WarehouseDocumentService:271`, `ProductionBatchController:46` and `:78` go negative — silently hiding items from the warehouse-receipt list. Reject with a clear message pointing the user at a warehouse write-off instead.

**`unsignedInteger` is a real constraint.** `produced_quantity` and `defect_quantity` are `unsignedInteger` (verified in `2026_04_11_000003_create_production_batch_items_table.php`). A decrement below zero **throws** under strict mode rather than clamping. Every path that lowers a counter must guard first, inside the transaction, with the row locked:

```php
$item = ProductionBatchItem::lockForUpdate()->find($id);

if ($item->produced_quantity - $item->warehouse_received_quantity < $qty) {
    throw ValidationException::withMessages([...]);
}
```

Do not rely on the FormRequest for this — validation runs outside the transaction and races.

### 2. Fix the validator (PROD-4)

Line 48 is the bug. Replace the whole `withValidator` allowance calculation:

```php
$produced         = (int) ($batchItem->produced_quantity ?? 0);
$defected         = (int) ($batchItem->defect_quantity ?? 0);
$warehouseReceived = (int) ($batchItem->warehouse_received_quantity ?? 0);

// Defects may come from EITHER the unproduced remainder OR from produced-but-not-yet-received units.
$unproducedRemainder = max(0, $batchItem->planned_quantity - $produced - $defected);
$scrappableProduced  = max(0, $produced - $warehouseReceived);

$remaining = $unproducedRemainder + $scrappableProduced;

if ($quantity > $remaining) {
    $validator->errors()->add(
        "items.{$index}.quantity",
        "Nuxson miqdori ({$quantity}) ruxsat etilgan chegaradan ({$remaining}) oshib ketdi. "
        . "Reja: {$batchItem->planned_quantity}, Tayor: {$produced}, "
        . "Nuxson: {$defected}, Omborda: {$warehouseReceived}.",
    );
}
```

Note what else this fixes: **drop the `$alreadyDefected` subquery entirely** (lines 51–52). It summed `defect_document_items` — the table that `destroy()` cascade-empties — while the allowance was computed from `produced_quantity`, which `destroy()` leaves inflated. The two sides disagreed by construction. `defect_quantity` on the item is now the single source (and reconcile proves it against the log), so the double-count guard is inherent rather than bolted on.

`$unproducedRemainder` now subtracts `$defected`, which line 48 never did — that is the guard the `$alreadyDefected` query was standing in for, done correctly.

### 3. Decide defect vs scrap at write time

In `store()`, per item, inside the existing transaction (line 41), with the row locked:

```php
$item = ProductionBatchItem::lockForUpdate()->find($itemData['production_batch_item_id']);
$qty  = (int) $itemData['quantity'];

$unproducedRemainder = max(0, $item->planned_quantity - $item->produced_quantity - $item->defect_quantity);

// Consume the unproduced remainder first; only then condemn produced units.
$fromRemainder = min($qty, $unproducedRemainder);
$fromProduced  = $qty - $fromRemainder;

if ($fromProduced > 0 && ($item->produced_quantity - $item->warehouse_received_quantity) < $fromProduced) {
    throw ValidationException::withMessages([
        'items' => ["Item {$item->id}: {$fromProduced} unit(s) are already in the warehouse. "
                  . "Record a warehouse write-off instead."],
    ]);
}

// Always: the units are defective.
ProductionEvent::create([
    'production_batch_item_id' => $item->id,
    'event_type' => ProductionEvent::TYPE_DEFECT,
    'quantity'   => $qty,                       // positive
    'occurred_at'=> $document->datetime,
    'user_id'    => $request->user()->id,
    'reason'     => $request->input('description'),
    'created_at' => now(),
]);
$item->increment('defect_quantity', $qty);

// Additionally: condemned units were previously counted as good.
if ($fromProduced > 0) {
    ProductionEvent::create([
        'production_batch_item_id' => $item->id,
        'event_type' => ProductionEvent::TYPE_SCRAP,
        'quantity'   => -$fromProduced,         // negative
        'occurred_at'=> $document->datetime,
        'user_id'    => $request->user()->id,
        'reason'     => $request->input('description'),
        'created_at' => now(),
    ]);
    $item->decrement('produced_quantity', $fromProduced);
}
```

"Remainder first" is the right default: if 500 are planned, 480 labelled and QC finds 5 faults, those 5 are almost certainly among the 20 not yet woven off the loom. Only once the remainder is exhausted are you condemning something already counted good.

`store()` is now doing far too much for a controller. Extract this into `app/Services/DefectDocumentService.php` mirroring `ProductionBatchService` — the transaction, the locking, the event writes. The controller should validate and delegate.

### 4. Reverse on delete instead of leaking (PROD-2)

`destroy()` must append reversing events and correct the counters, in one transaction, before the cascade wipes the items:

```php
public function destroy(DefectDocument $defectDocument, Request $request): JsonResponse
{
    DB::transaction(function () use ($defectDocument, $request): void {
        // MUST read items before delete() — cascadeOnDelete removes them.
        $items = $defectDocument->items()->get();

        foreach ($items as $docItem) {
            $item = ProductionBatchItem::lockForUpdate()->find($docItem->production_batch_item_id);
            if (! $item) {
                continue;   // item hard-deleted by ProductionBatchService::update(); nothing to reverse
            }

            $qty = (int) $docItem->quantity;

            // How much of this document's defect was a scrap of produced units?
            $scrapped = (int) ProductionEvent::where('production_batch_item_id', $item->id)
                ->where('event_type', ProductionEvent::TYPE_SCRAP)
                // ... scoped to this document — see note below
                ->sum('quantity');   // negative

            ProductionEvent::create([
                'production_batch_item_id' => $item->id,
                'event_type' => ProductionEvent::TYPE_DEFECT,
                'quantity'   => -$qty,                    // reversing entry
                'occurred_at'=> now(),                    // the reversal happens NOW, not at the original datetime
                'user_id'    => $request->user()->id,
                'reason'     => "Reversal of defect document #{$defectDocument->id}",
                'created_at' => now(),
            ]);
            $item->decrement('defect_quantity', min($qty, $item->defect_quantity));

            if ($scrapped < 0) {
                ProductionEvent::create([
                    'production_batch_item_id' => $item->id,
                    'event_type' => ProductionEvent::TYPE_SCRAP,
                    'quantity'   => -$scrapped,           // positive: undo the scrap
                    'occurred_at'=> now(),
                    'user_id'    => $request->user()->id,
                    'reason'     => "Reversal of defect document #{$defectDocument->id}",
                    'created_at' => now(),
                ]);
                $item->increment('produced_quantity', -$scrapped);
            }
        }

        foreach ($defectDocument->photos as $photo) {
            Storage::disk('public')->delete($photo->path);
        }

        $defectDocument->delete();
    });

    return response()->json(['message' => 'Nuxson hujjati o\'chirildi.']);
}
```

Three things to get right:

- **`occurred_at = now()`, not the original document's datetime.** The reversal is a *new fact that happened today*. Backdating it would retroactively rewrite a closed period in step 04's report and break the immutability that `resolveTtl` depends on. Reversing entries are dated when the reversal occurs — that is standard ledger practice and it is what keeps history stable.
- **You need to link scrap events back to their document.** The sketch above cannot scope the scrap sum to one document — `production_events` has no `defect_document_id`. Options, pick one and be explicit:
  - **(Recommended)** Add a nullable `defect_document_id` FK to `production_events` in this step's migration. Cleanest, makes the reversal exact, and is additive.
  - Or store the document id in `reason` and parse it — do not do this.
  - Or record the split (`from_remainder` / `from_produced`) on `defect_document_items` as a new nullable column. Also fine, and keeps `production_events` generic.
- **The counters are still decremented.** They are caches — step 01's whole design is that the cache is written in the same transaction as the log. `min($qty, $item->defect_quantity)` guards the unsigned column against the pre-existing inflation described below.

**Consider whether `destroy()` should exist at all.** Add `SoftDeletes` to `DefectDocument` so the document survives as evidence, and reconsider whether a defect document should be deletable rather than voidable. A physical carpet was inspected and judged faulty; that is a fact, and facts get reversed, not erased. Out of scope for the effort estimate here — raise it with the owner.

### 5. Repair the damage already done

`defect_quantity` is inflated **right now** on live by every defect document ever deleted. Step 03's backfill wrote opening events from these inflated counters, so the ledger currently agrees with a wrong number — reconcile will report clean and the corruption will sail straight through.

The honest position: **the true value is unrecoverable.** The `defect_document_items` rows were cascade-deleted, `DefectDocument` has no `SoftDeletes`, so there is no record of what was deleted or by how much. You cannot compute the correct `defect_quantity` from anything that still exists.

What you can do:

1. **Size the problem** — find items whose defect counter has no documents behind it:
   ```sql
   SELECT i.id, i.planned_quantity, i.produced_quantity, i.defect_quantity,
          COALESCE(SUM(di.quantity), 0) AS documented_defects,
          i.defect_quantity - COALESCE(SUM(di.quantity), 0) AS phantom
   FROM production_batch_items i
   LEFT JOIN defect_document_items di ON di.production_batch_item_id = i.id
   WHERE i.defect_quantity > 0
   GROUP BY i.id
   HAVING phantom <> 0
   ORDER BY phantom DESC;
   ```
   Every row is a deleted defect document. `phantom` is how inflated that item is.
2. **Take the list to the owner.** Only the floor can say which are real. Do not guess.
3. **Correct what he confirms** with explicit `defect` events (`reason = 'phantom defect repair, approved <date>'`) plus the matching counter decrement, in one transaction. Never a bare `UPDATE`. That is the whole point of this phase: the repair itself is an event, and next month someone can see it happened and why.
4. **Leave the rest.** An inflated counter you have flagged and documented beats a number you invented.

Do this **after** the `destroy()` fix ships, or you will repair items that get re-inflated the same week.

## How to verify

No test suite. Staging, by hand.

1. **PROD-4, the headline.** Take a batch item and label it to completion (`produced == planned`). Under current code, posting a defect document returns 422 with *"ruxsat etilgan chegaradan (0) oshib ketdi"*. Reproduce that first — confirm the bug is real. Then deploy and post again:
   ```bash
   curl -X POST https://<host>/api/v1/production-batches/<BATCH>/defect-documents \
     -H "Authorization: Bearer <TOKEN>" -H "Accept: application/json" \
     -F "description=QC found weaving fault on finished carpet" \
     -F "items[0][production_batch_item_id]=<ITEM>" \
     -F "items[0][quantity]=3"
   ```
   Must return **201**. Then:
   ```sql
   SELECT produced_quantity, defect_quantity FROM production_batch_items WHERE id = <ITEM>;
   SELECT event_type, quantity, reason FROM production_events
   WHERE production_batch_item_id = <ITEM> ORDER BY id DESC LIMIT 4;
   ```
   `produced` down 3, `defect` up 3, sum unchanged. Two events: `('scrap', -3)` and `('defect', +3)`.
2. **Remainder-first split.** Item with `planned=10, produced=8, defect=0`. Post a defect of 3. Expect: 2 from remainder, 1 scrapped → `produced=7, defect=3`. Events: `('defect', +3)` and `('scrap', -1)`. Post a defect of 1 to a fully-labelled item → `('defect', +1)` and `('scrap', -1)`, no remainder consumed.
3. **Warehouse boundary rejects.** Item with `produced=5, warehouse_received=5`. Post a defect of 1 → must 422 with the write-off message. Confirm `produced_quantity` did **not** move (this is the unsigned-column trap; a bad implementation throws a 500 SQL error here instead of a clean 422 — check which you get).
4. **PROD-2, the delete.** Post a defect document for 5, note `defect_quantity`. `DELETE /api/v1/defect-documents/<ID>`. Then:
   ```sql
   SELECT defect_quantity FROM production_batch_items WHERE id = <ITEM>;
   SELECT event_type, quantity, occurred_at, reason FROM production_events
   WHERE production_batch_item_id = <ITEM> ORDER BY id DESC LIMIT 4;
   ```
   `defect_quantity` back to its pre-document value; a `('defect', -5)` reversal with `reason` naming the document and `occurred_at` = today. The original `+5` must **still be there** — append-only. If the original row is gone, the implementation is mutating the log; reject it.
5. **Delete a scrap-bearing document.** Repeat #4 for a document that scrapped produced units. `produced_quantity` must come back up, `defect_quantity` down, and four events total (2 original, 2 reversing).
6. **Reconcile stays clean throughout.** After every step above, run step 03's reconcile query (verification #5). Zero rows, always. If a scrap breaks it, the event-type mapping is wrong.
7. **Batch auto-completion.** With `produced=495, planned=500, defect=5`, confirm the batch completes correctly via line 173's check, and that reversing the defect document *reopens* the arithmetic (`produced=495 < 500-0`) — note the batch will **not** automatically return to `in_progress`; `checkAndCompleteProductionBatch` (line 111) only ever completes. Flag it if the owner cares; it is out of scope here.
8. **Concurrency.** Two simultaneous defect documents against the same item, together exceeding `remaining`. Exactly one must succeed. If both do, the `lockForUpdate` is missing or the check is in the FormRequest (which runs outside the transaction) rather than in the service.

## Rollback

Harder than the earlier steps — this one writes real data.

- **Code:** revert the request, controller, and service. The validator returns to rejecting defects on finished carpets (bug restored, no corruption). `destroy()` returns to leaking (bug restored).
- **Data:** scrap events written while this was live have already moved `produced_quantity` down. Reverting the code does **not** put it back, and the numbers are correct as they stand — leave them. Do not "undo" the scraps; they represent real condemned carpets.
- If you must fully unwind, reverse each scrap with a compensating pair — again as **events**, never a bare `UPDATE`:
  ```sql
  SELECT production_batch_item_id, SUM(quantity)
  FROM production_events
  WHERE event_type = 'scrap' AND created_at >= '<deploy timestamp>'
  GROUP BY production_batch_item_id;
  ```
- **The phantom-defect repair (§5) has no rollback.** The pre-repair values are gone. Snapshot before you touch anything:
  ```sql
  CREATE TABLE _defect_qty_backup_20260714 AS
  SELECT id, produced_quantity, defect_quantity, NOW() AS snapshot_at FROM production_batch_items;
  ```
  Do this. It costs nothing and it is the only way back.

## Depends on / blocks

- **Depends on: 01** — `production_events`, the model, and the event-type mapping. The scrap/defect split is meaningless without the log.
- **Depends on: 03** if you intend to run the phantom-defect repair — reconcile must be clean before you can tell a phantom from a gap in the ledger.
- **Interacts with 04:** scrap events carry negative quantities into the produced sum. Step 04's `whereIn(event_type, ['produced','scrap','correction'])` already accounts for this. If 04 has shipped, expect production figures to *drop* on days when finished carpets are condemned — correct, and worth warning the owner about, because it will be the first time the report has ever gone down.
- **Blocks: 06** in practice — reconcile cannot meaningfully assert on `defect_quantity` while `destroy()` is still leaking, since drift would be permanent and expected rather than alarming.
