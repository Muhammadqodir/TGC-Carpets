# 02 — Production units and serials

Give every physical carpet its own identity, so that counting, tracing and receiving stop being guesswork.

**Severity: High / Effort: 3 weeks / Safe on live: Partially — new table and dual-run are safe; the client release and label change are a coordinated cutover**

## Why this matters

Today a carpet has no identity. The unit of record is the *batch line*, and quantity is an integer on it.

### The QR code identifies a batch line, not a carpet

`tgc_backend/app/Http/Controllers/Api/V1/ProductionBatchController.php` line 316 is `scanItem()`. Its parser is line 321:

```php
if (!preg_match('/PB\{(\d+)\}\s+PBI\{(\d+)\}/', $code, $matches)) {
    return response()->json(['message' => 'Invalid QR code format. Expected: PB{batchId} PBI{itemId}'], 400);
}
```

It resolves `$batchId` and `$itemId` and loads a `ProductionBatchItem` (lines 328–339). A batch line with `planned_quantity = 50` is one row. So all 50 physical carpets cut from that line carry a byte-identical QR code. Scanning any one of them returns the line, never the carpet. You cannot tell two carpets apart, which means you cannot answer "where is *this* carpet" for any carpet in the factory.

### Correction to the brief: the scan endpoint is dead in production

While verifying the above I found that **no label the client prints can be scanned at all**. There are three QR formats in the Flutter client and none of them match the backend regex:

| Client source | Format produced | Backend regex verdict |
|---|---|---|
| `tgc_client/lib/features/labeling/presentation/pages/print_history_page.dart:276` | `PB{12} VAR{34}` | **400** |
| `tgc_client/lib/features/labeling/presentation/pages/labeling_page.dart:685` | `P12 I34` | **400** |
| `tgc_client/lib/features/labeling/presentation/pages/labeling_page.dart:480` | `P1 I1` (preview) | **400** |
| backend's own documented format (line 313) | `PB{12} PBI{34}` | 200 |

Verified by running the actual regex against the actual strings:

```
PB{12} PBI{34}     backend doc format               => MATCH (200)
PB{12} VAR{34}     print_history_page.dart:276      => NO MATCH (400)
P12 I34            labeling_page.dart:685           => NO MATCH (400)
P1 I1              labeling_page.dart:480           => NO MATCH (400)
```

`print_history_page.dart:276` emits `VAR{variantId}` — a *variant* id where the backend wants a *batch item* id. Those are different tables with different id spaces, so even a lenient parser would resolve the wrong row. `labeling_page.dart:685` omits the braces entirely.

`GET /api/v1/production-batches-scan` (`routes/api.php` line 165) therefore returns `400 Invalid QR code format` for every label in the building. This is a fourth instance of the Phase 0 "endpoint completely dead" class, and it strengthens the case for the smoke test in `01-tests-and-ci.md`.

**Consequence for this work:** there is no scanning behaviour to preserve. Nobody can be relying on it. You are not migrating a working feature — you are building one for the first time. That removes most of the cutover risk from the backend side and means you should not spend time on a compatibility parser for the legacy formats (see The change, step 6).

### Printing a label inflates the count

`ProductionBatchController::printLabel()` (line 298) calls `ProductionBatchService::incrementProducedQuantity()` (line 164):

```php
DB::transaction(function () use ($item): void {
    $item->increment('produced_quantity');
    // ...
    if ($allLabeled) {
        $batch->update([
            'status'             => ProductionBatch::STATUS_COMPLETED,
            'completed_datetime' => now(),
        ]);
```

A blind `increment()` with no idempotency key. Concretely: a line plans 50 carpets. The printer jams on carpet 37, the operator reprints, `produced_quantity` becomes 51 with 50 carpets on the floor. Worse, lines 172–180 auto-complete the batch when `produced_quantity >= planned_quantity - defect_quantity`, so three reprints can mark a batch **completed** while thirteen carpets are still on the loom. The count is not merely inaccurate; it drives state transitions.

There is no way to detect this after the fact, because nothing distinguishes "printed 51 labels for 50 carpets" from "made 51 carpets".

### What serials fix

| Question | Today | With `production_units` |
|---|---|---|
| How many did we make? | `produced_quantity`, inflated by every reprint | `COUNT(*)` of real labelled units |
| Reprint a damaged label | +1 to the count, forever | reuse the serial, count unchanged |
| Carpet found defective after labelling | decrement a counter and hope | `status = 'defect'` on that row |
| Which loom/operator/date made this one? | unanswerable | one row lookup |
| Warehouse receives 50, which 50? | allocation is a guess | scan the serials |

## Files to change

Backend:
- new migration `tgc_backend/database/migrations/xxxx_create_production_units_table.php`
- new `tgc_backend/app/Models/ProductionUnit.php`
- `tgc_backend/app/Services/ProductionBatchService.php` — `incrementProducedQuantity()` line 164
- `tgc_backend/app/Http/Controllers/Api/V1/ProductionBatchController.php` — `printLabel()` line 298, `scanItem()` line 316 (regex line 321)
- `tgc_backend/app/Services/WarehouseDocumentService.php` — `syncItems()` line 133, `creditProductionBatchItems()` call at line 172
- `tgc_backend/routes/api.php` — line 165 area

Client (needs a release):
- `tgc_client/lib/features/labeling/presentation/pages/labeling_page.dart` lines 480, 685
- `tgc_client/lib/features/labeling/presentation/pages/print_history_page.dart` lines 273–276
- `tgc_client/lib/features/labeling/presentation/widgets/labels/print_label_70_50.dart` line 142 (`data: qrData`)
- `tgc_client/lib/features/labeling/presentation/widgets/labels/print_label_70_50_arab.dart` line 141
- `tgc_client/lib/features/labeling/presentation/args/print_labels_args.dart` line 13 (`qrData`)
- `tgc_client/lib/features/scanner/` — datasource calls `/production-batches-scan` (`scanner_remote_datasource.dart` line 16)

Label rendering (no change expected, but check):
- `usb_label_print/lib/src/label_renderer.dart`, `label_widget.dart`, `label_config.dart`

The label widgets take `qrData` as an opaque string and hand it to a QR painter, so **the label template itself does not need to change** — only the string passed in. Confirm the 14-character serial scans reliably at the current QR module size on the 70×50 mm label before committing to the format; if it does not, `label_config.dart` is where size lives.

## The change

### 1. The table

```sql
CREATE TABLE production_units (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    production_batch_item_id BIGINT UNSIGNED NOT NULL,
    serial CHAR(14) NOT NULL,               -- TGC-U-00001234, goes in the QR
    printed_by BIGINT UNSIGNED NOT NULL,
    printed_at DATETIME NOT NULL,
    status ENUM('good','defect','scrapped','received','shipped') NOT NULL,
    warehouse_document_item_id BIGINT UNSIGNED NULL,
    shipment_item_id BIGINT UNSIGNED NULL,
    UNIQUE KEY uniq_serial (serial)
);
```

Add to the proposed schema before writing the migration:

- `created_at` / `updated_at` — every other table has them; the audit work in `06-audit-log.md` will want them.
- `reprint_count INT UNSIGNED NOT NULL DEFAULT 0` — reprints are the thing you are trying to make visible. Count them instead of discarding the fact.
- foreign keys: `production_batch_item_id` → `production_batch_items.id` `restrictOnDelete`; `printed_by` → `users.id`; `warehouse_document_item_id` → `warehouse_document_items.id` `nullOnDelete`; `shipment_item_id` → `shipment_items.id` `nullOnDelete`.
- indexes: `(production_batch_item_id, status)` — this is the count query, and it runs on every batch view. `(status)` alone is too low-cardinality to help.

`CHAR(14)` fits `TGC-U-` + 8 digits exactly. That caps you at 100 million units; at any plausible factory rate that is fine. Note the existing client already uses a similar shape for variant barcodes — `TGC-VAR-%08d` at `print_history_page.dart:275` and `TGC-%08d` at `labeling_page.dart:684` — so `TGC-U-%08d` is consistent and unambiguous against both.

Allocate serials from the table's own auto-increment inside the print transaction. Do not use a separate counter table or `MAX(id)+1`; both race.

### 2. Status semantics

Write these down in the model as constants and do not let them drift:

- `good` — printed, on the floor, not yet received into a warehouse
- `defect` — found defective at any point; excluded from produced counts
- `scrapped` — physically destroyed; terminal
- `received` — booked into a warehouse by a document
- `shipped` — left on a shipment

`produced_quantity` is then reconcilable as:

```sql
SELECT COUNT(*) FROM production_units
WHERE production_batch_item_id = ?
  AND status IN ('good','received','shipped');
```

A unit that is `defect` or `scrapped` is not produced output. A `received` or `shipped` unit was produced and still counts — which is why the `IN` list is not just `good`.

### 3. Print becomes idempotent

Current `printLabel()` → `incrementProducedQuantity()` → blind `+1`.

Intended: `printLabel()` takes an optional `serial`. If absent, mint a new unit (new serial, `reprint_count = 0`). If present and the serial exists, this is a **reprint**: return the same serial and `reprint_count++`, and do not touch any count. Double-counting becomes structurally impossible rather than a thing operators are told not to do.

```php
public function printUnit(ProductionBatchItem $item, int $userId, ?string $serial = null): ProductionUnit
{
    return DB::transaction(function () use ($item, $userId, $serial): ProductionUnit {
        if ($serial !== null) {
            $existing = ProductionUnit::where('serial', $serial)->lockForUpdate()->first();
            if ($existing) {
                $existing->increment('reprint_count');
                return $existing;
            }
        }

        $unit = ProductionUnit::create([
            'production_batch_item_id' => $item->id,
            'serial'                   => 'PENDING',
            'printed_by'               => $userId,
            'printed_at'               => now(),
            'status'                   => ProductionUnit::STATUS_GOOD,
        ]);

        $unit->update(['serial' => sprintf('TGC-U-%08d', $unit->id)]);

        return $unit;
    });
}
```

The `PENDING` two-step exists because the serial derives from the auto-increment id. `serial` is `NOT NULL UNIQUE`, so `PENDING` can only ever exist for one row at a time inside a transaction — which is precisely the serialisation you want, but it means concurrent printers block on each other. If two label stations print simultaneously and you measure contention, switch to a `unit_serials` sequence table or derive the serial from a `bigint` allocated by `nextval`-style `UPDATE ... SET id = LAST_INSERT_ID(id+1)`. Do not skip the uniqueness guarantee to avoid the lock.

Keep the auto-complete logic (lines 172–180) but drive it from the unit count, not the counter. Note it becomes *correct* for free: reprints no longer advance it.

### 4. Scan resolves a carpet

Replace the regex at line 321. The new code is the bare serial — no wrapper syntax, no braces, nothing to get wrong across two codebases:

```php
$code = trim((string) $request->input('code'));

if (! preg_match('/^TGC-U-\d{8}$/', $code)) {
    return response()->json(['message' => 'Invalid code. Expected a unit serial, e.g. TGC-U-00001234.'], 400);
}

$unit = ProductionUnit::with([
        'batchItem.productionBatch' => fn ($q) => $q->with(['machine', 'creator', 'responsibleEmployee']),
        'batchItem.variant.productColor.product.productType',
        'batchItem.variant.productColor.product.productQuality',
        'batchItem.variant.productColor.color',
        'batchItem.variant.productSize',
        'batchItem.variant.productEdge',
        'batchItem.sourceOrderItem.order.client',
    ])
    ->where('serial', $code)
    ->first();

if (! $unit) {
    return response()->json(['message' => 'Unit not found.'], 404);
}
```

The eager-load list is the existing one from lines 328–339 with `batchItem.` prepended. The response gains the fields only a serial can provide: `serial`, `status`, `printed_at`, `printed_by`, and the warehouse/shipment links. Loom, operator, date, order and client all come through the existing relations — that part already worked, it was simply unreachable.

### 5. Warehouse receipt scans real serials

`WarehouseDocumentService::syncItems()` line 172 currently calls `creditProductionBatchItems($variant->id, $quantity)` on a `TYPE_IN` document — it takes a variant and a number and spreads that number across batch items by some rule. That is the guess this work removes.

Intended: a receipt line may carry `serials[]`. When present, set each unit's `status = 'received'` and `warehouse_document_item_id`, and derive the quantity from the count rather than trusting a typed integer. Keep the old path for lines without serials during the dual-run.

Guard rails, all of which are now expressible for the first time:
- reject a serial already `received` (double receipt)
- reject a serial whose `status` is `defect` or `scrapped`
- reject a serial whose variant does not match the document line's variant
- assert `count(serials) === quantity`

### 6. Do not write a compatibility parser

Because the scan endpoint is already 400-ing on every real label (see Why this matters), there is no installed base of scannable labels to support. Accept only `TGC-U-\d{8}`. Adding a legacy branch for `PB{x} PBI{y}` would be code that has never once succeeded in production.

Carpets labelled *before* this ships have QR codes that decode to `PB{..} VAR{..}` or `P.. I..` and have no unit row. They were never scannable and will not become scannable. If historical stock must be brought into the scheme, that is a relabelling exercise on the floor, not a software compatibility layer — cost it separately and decide explicitly. Relabelling only the stock still in the warehouse is usually the right call; carpets already shipped do not matter.

### 7. Run alongside the counters, do not replace them

Ship in this order. Do not compress it.

1. Migration + model + backfill (below). Nothing reads it. Zero risk.
2. Backend writes units on print **and** keeps `increment('produced_quantity')`. Both run. Zero client change.
3. Add a reconciliation endpoint or command comparing `produced_quantity` against the unit count per batch item. Watch it for two full production weeks.
4. Client release: print the serial, scan the serial. Old clients still work because step 2 keeps the counter path alive.
5. Only once every label station is on the new client and reconciliation has been clean for two weeks, make the unit count authoritative and demote `produced_quantity` to a cache.

Step 3 is where the value is even if you stop there: it tells you, for the first time, how far the counters have drifted. Expect the unit count to be *lower* than `produced_quantity` — the gap is the accumulated reprints.

Backfill for step 1 — one synthetic unit per already-counted carpet, so the count matches on day one:

```sql
INSERT INTO production_units
    (production_batch_item_id, serial, printed_by, printed_at, status, created_at, updated_at)
SELECT pbi.id,
       CONCAT('TGC-U-', LPAD(@row := @row + 1, 8, '0')),
       COALESCE(pb.responsible_employee_id, pb.created_by),
       pbi.updated_at,
       'good',
       NOW(), NOW()
FROM production_batch_items pbi
JOIN production_batches pb ON pb.id = pbi.production_batch_id
JOIN (SELECT @row := 0) init
JOIN numbers n ON n.n <= pbi.produced_quantity;
```

This needs a `numbers` helper table (or a recursive CTE — MySQL 8 supports it, and the production server is MySQL). **The backfilled serials do not correspond to any physical label**, because the carpets they represent were labelled with the old unscannable QR. Set `printed_by` from the batch and accept that `printed_at` is `updated_at`, which is approximate. Mark these rows so you can tell them apart later — add a nullable `backfilled_at DATETIME` column, or accept that `id <= <max at backfill>` identifies them. Do not pretend backfilled rows are traceable units; they exist to make the count reconcile, nothing more.

Also reset the auto-increment above the backfilled range before real printing starts, so no live serial can collide with a synthetic one.

## Relationship to Phase 2 `production_events`

Be explicit about this or the two designs will fight.

**`production_units` supersedes `production_events` for the `produced` event type.** Once a unit row exists per carpet, a `produced` event carrying `quantity: +1` is a strictly weaker statement of the same fact — the unit row says everything the event says plus which carpet it was. Do not write both for the same physical act; you will have two counts that drift, which is the problem you started with.

Events remain useful and should be kept for:
- corrections and adjustments that are not a single carpet ("this batch's count was wrong by −3 before serials existed")
- status transitions where the *reason* matters (`reason` field) — a unit going `good` → `defect` is a fact worth an event, because the unit row only holds the current status
- anything pre-dating the serial cutover

Concretely: `production_units` is the state, `production_events` is the log of *why the state changed*. If Phase 2 ships an event per produced carpet, plan to stop emitting that specific event type at step 5 above and let `COUNT(*)` be the answer.

## How to verify

1. Print a label for a batch item. A `production_units` row appears; `serial` matches `TGC-U-\d{8}`; the QR on the physical label decodes to exactly that string (scan it with a phone).
2. Reprint the same serial. `reprint_count` becomes 1. `COUNT(*)` for the batch item is unchanged. This is the bug being fixed — verify it explicitly.
3. `GET /api/v1/production-batches-scan?code=TGC-U-00000001` returns loom, operator, printed date, order and client for that one carpet.
4. Scan a serial that does not exist → 404, not 500.
5. Send `PB{1} PBI{1}` → 400. Send `PB{1} VAR{1}` → 400. Both are correct; neither ever worked.
6. Mark a unit `defect`. The batch item's produced count drops by one. `planned − defect` completion logic still behaves.
7. Receive 10 scanned serials into a warehouse document. All 10 rows go `received` with `warehouse_document_item_id` set. Re-submitting the same serial is rejected.
8. Reconciliation report: for every batch item, `produced_quantity` vs unit count. Investigate every non-zero delta before step 5.
9. Print from a **pre-release client** against the new backend. It must still work (step 2 dual-run). If it does not, you have broken the factory.

## Rollback

- Steps 1–3: drop the table. Nothing reads it.
- Step 4 (client shipped): the backend still maintains `produced_quantity`, so rolling the client back to the previous build restores the old behaviour exactly — the old client's labels were never scannable, so nothing is lost that was working. Keep the previous client build downloadable for the whole dual-run.
- Step 5 is the one-way door. Do not take it until reconciliation has been clean for two weeks. After it, `produced_quantity` is a cache and rolling back means trusting a number you have stopped maintaining.

## Depends on / blocks

- **Depends on `01-tests-and-ci.md`.** This changes the print path, which is the single most load-bearing operation in the building. Do not attempt it without the smoke test, and add a ledger test for the unit lifecycle.
- **Depends on Phase 2** only for the `occurred_at` discipline and the reconcilable-cache framing. It does not need the `production_events` table to exist, and it partly supersedes it — see above.
- **Blocks `07-stock-reservations.md`.** Reserving a specific carpet is far more useful than reserving a count, and reservations against serials are exact. Reservations will work without this, so 07 is not strictly gated, but doing 02 first makes 07 simpler.
- **Blocks `08-defect-rate-and-yield-metrics.md`** in practice: first-pass yield is `good / (good + defect + scrapped)` per unit, which is a clean query against this table and a fudge without it.
- **Requires a coordinated client release.** The Flutter client and the label stations must be updated together. Budget for a week of dual-run before the cutover and do not schedule the cutover near a large order deadline.
