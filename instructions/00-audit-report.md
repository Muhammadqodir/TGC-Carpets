# TGC Carpets ERP — backend & data structure audit

**Date:** 14 July 2026
**Scope:** `tgc_backend` — 28 models, 59 migrations, ~9,300 lines. Production, warehouse, stock, orders, shipments, payments, analytics.
**Method:** source reading. No code was executed against the live system.

Findings counted: **9 critical, 12 high, 12 medium, 14 low.** Tests in the repo: **0**.

> **Revision, 14 July 2026 (later same day).** While writing the step-by-step instructions, three further defects were verified that this report originally missed — a second fatal bug in the dashboard (`shipment_items.total` no longer exists), the QR scan endpoint rejecting every label the client prints (`SCAN-1`), and a fifth foreign key that the variant-merge must repoint. All are folded in below. The published HTML report predates this revision; **this file is canonical.**

---

## The short version

**1. Production reports are dated by `updated_at`.** Every produced quantity is attributed to the day the row was *last touched* — which a warehouse receipt, a defect entry, or a notes edit silently overwrites months later. March's output moves into July by itself. This alone explains most of "sometimes calculations are not correct".

**2. `production_batch_items` stores counters with no events behind them.** There is no record of who printed a label, when, or why a number changed — so the counters cannot be audited, corrected, or recomputed, and three code paths already let them drift permanently out of sync with reality.

**3. Three endpoints are dead in production right now** — the dashboard 500s on every call (for two independent reasons), warehouse document editing fails 100% of the time, and the QR scanner rejects every label the factory has ever printed. All are small fixes. None has a test that would have caught it.

---

## 01 — Why the calculations are wrong

### CALC-1 — Production is dated by `updated_at`, not by when production happened
**Critical.** Verified directly. → `phase-2/04`

`app/Services/ProductionAnalyticsService.php:58`

```php
->whereBetween(DB::raw('DATE(production_batch_items.updated_at)'), [$from, $to])
```

`updated_at` is not a production date — it is a "last touched" stamp. Four paths rewrite it long after the carpet was woven:

- `WarehouseDocumentService.php:283` — `increment('warehouse_received_quantity')`, fires on **every warehouse receipt**
- `WarehouseDocumentService.php:309` — `decrement(...)` on reversal
- `DefectDocumentController.php:57` — `increment('defect_quantity')`
- `ProductionBatchService.php:207` — `updateItem()`; editing the *notes* field alone re-dates the production

Worse, `produced_quantity` is a lifetime cumulative counter, not a per-day figure. So the item's *entire output* lands on whatever date last touched the row.

**Failure scenario.** A batch item of 500 carpets, woven 5–7 January. Warehouse receives them 20 January.

1. The 5–7 January report now shows **0** produced.
2. The 20 January report shows **500** — on a day nothing was made.
3. On 14 July someone files a defect document against that item. The January report **retroactively drops to 0** and July gains 500.

January's report returns different numbers today than it did in January, from production data that never changed. Nothing errors; the totals just quietly move.

This is a *symptom of the missing event log*, not an independent defect. A stopgap (`first_produced_at` column) is possible but only papers over the cumulative-counter half.

### CALC-2 — `/dashboard/stats` throws HTTP 500 on every request — twice over
**Critical.** Verified directly. → `phase-0/01`

**Bug 1.** `app/Http/Controllers/Api/V1/DashboardController.php:43` uses `StockMovement::TYPE_IN`, but the file's imports are only `Controller`, `WarehouseDocument`, `JsonResponse`, `Request`, `DB`. PHP resolves it to `App\Http\Controllers\Api\V1\StockMovement`, which does not exist.

**Bug 2.** Line 59 does `->sum('shipment_items.total')`, but `database/migrations/2026_04_16_000001_drop_total_from_shipment_items_table.php` **dropped that column** and nothing re-adds it (`ShipmentItem::$fillable` confirms: `shipment_id`, `order_item_id`, `product_variant_id`, `quantity`, `price`). Fixing the import alone just swaps a PHP fatal for `SQLSTATE[42S22]: Unknown column 'shipment_items.total'`.

The line total is now *derived*, so restoring `shipments_amount` correctly means using the shared formula from `phase-1/01` — reproducing it inline would make it a **fifth** copy of CALC-3. See the step file for the two options.

The Flutter client calls this endpoint (`dashboard_remote_datasource.dart:25`). Not "sometimes wrong" — the dashboard is down, and has been since the `Improved stock calculations` commit.

### CALC-3 — The same shipment total is computed four times, three different ways
**High.** → `phase-1/01`

There is no single money formula. `price × length × width × qty / 10000` is re-derived independently in four places that disagree about *where rounding happens*:

| Location | Rounding | Arithmetic |
|---|---|---|
| `ShipmentItemResource.php:48` | per line | PHP float |
| `ClientDebitService::getLedger:99` | per shipment | PHP float |
| `ClientDebitService::getSummaries:33` | **none at all** | MySQL DECIMAL |
| `shipment_hisob_faktura.blade.php:228` | per line | PHP float |

**Failure — invoice disagrees with ledger.** Two identical m² lines, price 10.00, size 55×105 cm (0.5775 m²). Raw line = 5.775.
- Invoice and API (per line): 5.78 + 5.78 = **11.56**
- Ledger (per shipment): round(5.775 + 5.775) = **11.55**

**Failure — fractional cents in the debit list.** A 33×33 cm carpet (0.1089 m²) at 12.35, qty 1:
- `getSummaries` (no rounding) → `"total_debit": 1.344915`
- `getLedger` and the invoice → **1.34**

The debit screen and the ledger screen can never be reconciled: one runs MySQL exact decimal arithmetic, the other PHP binary floats.

**Good news:** both money columns are genuine `DECIMAL` (`payments.amount decimal(14,2)`, `shipment_items.price decimal(12,2)`). No float money columns, no stored totals to drift. The formula was copy-pasted rather than shared.

### CALC-4 — The `hisob-faktura` invoice multiplies quantity twice in the m² columns
**High.** → `phase-0/07`

`resources/views/.../shipment_hisob_faktura.blade.php:224` computes `$sqm` *already including* `$qty`, then line 250 prints it as the per-unit column and line 258 prints `$sqm * $qty` as the total — qty².

60×110 cm, qty 10, price 12.00/m²: the *m²* column shows **6.60** (should be 0.66), *Jami m²* shows **66.00** (should be 6.60), while the grand total *Umumiy m²* correctly shows **6.60** and the line money is correctly **79.20**. The invoice contradicts itself in front of the client. The sibling template `shipment_invoice.blade.php:243` gets it right, which proves it's a bug rather than a convention.

### CALC-5 — Three smaller reporting defects
**Medium.** → `phase-0/08`, `phase-0/10`

- **Empty date params silently zero the report.** `ProductAnalyticsRequest.php:26` uses `$this->input('period_from', $default)` — the default only applies when the key is *absent*. A cleared date picker sends `?period_from=`, passes `['nullable','date']`, produces `BETWEEN '' AND '2026-07-14'` → zero rows → every metric reports 0 with HTTP 200. Then cached for 5 minutes.
- **No cache invalidation anywhere.** Zero `Cache::forget`/`tags`/`flush` in `app/`. Historical ranges get a 60-minute TTL on the premise history doesn't change — CALC-1 proves it does.
- **Filtered top-products percentages exceed 100%.** `ProductAnalyticsService.php:84` re-derives breakdowns from a fresh *unfiltered* `baseQuery()`, then divides by the *filtered* total. Filter to red: total 100, breakdown shows red 100% *and blue 400%*.

---

## 02 — The `production_batch_items` problem

A label print does this, and only this (`ProductionBatchService.php:170`):

```php
$item->increment('produced_quantity');
```

So the row can tell you *how many*, but never **who** printed it (no `user_id` on the item), **when** (only `updated_at`, which four other paths overwrite), **why a number changed** (`PATCH .../items/{item}` lets anyone overwrite `produced_quantity` to any value, no reason, no trail), or **whether it's real** (the counter cannot be recomputed from anything).

### PROD-1 — Editing a batch silently destroys all production history
**Critical.** Verified directly. → `phase-0/06`, then `phase-2/01`

`ProductionBatchService.php:88` does `$batch->items()->delete()` then re-creates via `syncItems`, which sets only `planned_quantity`. So `produced_quantity`, `defect_quantity` and `warehouse_received_quantity` **reset to 0**, and rows get new IDs.

A batch 80% woven (produced 400 of 500), someone fixes a typo and PATCHes:
1. All recorded production vanishes — `produced_quantity = 0`.
2. Every QR label already glued to a carpet encodes `PBI{old_id}` → scanning returns 404 forever.
3. `warehouse_document_items.source_id` still points at deleted IDs — polymorphic, **no FK** (`2026_04_13_000002`), so the pointers just dangle.
4. If any defect document exists, `defect_document_items.production_batch_item_id` *is* a real FK with RESTRICT → raw SQL error → HTTP 500.

### PROD-2 — Deleting a defect document leaves the counter permanently inflated
**High.** Verified directly. → `phase-0/05`, then `phase-2/05`

`store()` increments `defect_quantity` (`DefectDocumentController.php:57`). `destroy()` deletes the document and cascade-deletes its items but **never decrements**. `DefectDocument` has no `SoftDeletes`, so the evidence is gone and the number stays.

Planned 100, a defect doc for 20 filed by mistake then deleted:
- `defect_quantity` = 20 forever; `DefectDocumentItem::sum()` = 0.
- Auto-complete checks `produced < (planned − defect)` → at produced 80, `80 < 80` is false → **batch completes at 80**. The last 20 carpets are never made.
- Validation computes remaining defect capacity from `DefectDocumentItem::sum()` (= 0), so it accepts 20 *more* → `defect_quantity` = 40 on a 100-unit item.

### PROD-3 — Label printing is not idempotent
**High.** Verified directly. → `phase-2/02`

`POST .../print-label` increments unconditionally. No idempotency key. In `labeling_bloc.dart:60` a failed request surfaces an error and the operator taps again. On factory Wi-Fi the server commits, the response times out, the operator retries: `produced_quantity` is now 2 for one physical carpet, with no record to find, prove, or undo it.

### PROD-4 — A finished carpet can never be marked defective
**High.** Verified directly. → `phase-2/05`

`StoreDefectDocumentRequest.php:47`:

```php
$available = max(0, $batchItem->planned_quantity - $produced);   // from the UNPRODUCED remainder
$remaining = max(0, $available - $alreadyDefected);
```

The model assumes `planned = produced + defect + remaining`. Once all labels are printed, `available = 0` and **every defect document is rejected**: *"Nuxson miqdori (5) ruxsat etilgan chegaradan (0) oshib ketdi"*.

The only workaround is PATCHing `produced_quantity` down by hand — untracked, unattributed, and it re-dates all 100 units into today's production report (CALC-1). This is a *modelling* gap: the schema has no concept of a unit produced and later condemned.

### The fix

**A quantity that can change over time is an event log, and any column holding a total is a cache of that log that must be reconcilable.** Right now there is a cache without the log.

**Level 1 — `production_events`** (recommended first step). Append-only; a mistake is corrected by appending a negative row with a reason. `produced_quantity` **stays** as a cache written in the same transaction, so every existing read keeps working. Plus `php artisan production:reconcile` nightly.

| Column | Answers | Kills |
|---|---|---|
| `user_id` | who added the quantity | the original question |
| `occurred_at` | when it was actually produced | CALC-1 |
| `idempotency_key` | is this a retry? | PROD-3 |
| `quantity` signed + `reason` | why the number changed | PROD-2, PROD-4 |
| append-only | can I recompute the truth? | PROD-1 |

**Level 2 — `production_units`**, one row per physical carpet. The QR encodes `PB{batchId} PBI{itemId}` (`ProductionBatchController.php:322`) — it identifies the *batch line*, not the carpet, so **all 50 carpets in a 50-unit line carry an identical QR code**. Per-unit serials make reprints idempotent by construction, let a labelled carpet be condemned, and answer "where is *this* carpet".

Ship Level 1 now. Treat Level 2 as the natural follow-on. Don't do both at once. Full schemas in `phase-2/01` and `phase-3/02`.

---

## 03 — Data structure defects

### STRUCT-1 — Variants have no unique constraint on their own identity
**Critical.** Verified directly. → `phase-1/04`, `phase-1/05`

A variant *is* the tuple (product_color, size, edge). `2026_04_07_000006:57` declares a plain `index(['product_color_id','product_size_id'])` — not unique, and `product_edge_id` isn't in it at all. The only unique keys are `barcode_value` and `sku_code`. `ProductVariantService` leans on catching `UniqueConstraintViolationException` — from `sku_code`, a *derived string* built from product name, colour name and size. SKU is doing load-bearing identity work it was never designed for.

And the two SKU generators disagree on axis order — `2026_04_07_000007:44` emits `CONCAT('-', ps.length, 'x', ps.width)`; `ProductVariant::generateSku()` (`app/Models/ProductVariant.php:57`) emits `$size->width . 'x' . $size->length`.

**Failure — stock splits in half.** The warehouse path calls `findOrCreate($color, $size)` **without the edge** (`WarehouseDocumentService.php:136`), while orders and production always pass it. `2026_06_07_000002` backfilled every existing variant with edge `R`. So the warehouse looks for `edge IS NULL` → never matches → generates a SKU `200x300` where the backfilled row is `300x200` → no collision → **a second variant row** for the same physical carpet.

Stock for one carpet now splits across two variant IDs. `/stock/variants` lists it twice. Worse, `creditProductionBatchItems()` looks up production by the *new* variant ID and matches nothing — `warehouse_received_quantity` is never credited, orders never auto-complete, and the item shows "ready to receive" forever, inviting the same receipt again.

### STRUCT-2 — Stock is a live SUM with nothing to lock
**Critical.** → `phase-1/03`, `phase-1/08`, `phase-2/07`

No cached balance anywhere; every read is `SUM()` over `stock_movements`. The ledger is authoritative (good) but **unlockable** (bad) — you cannot `SELECT … FOR UPDATE` an aggregate. `assertSufficientStock()` is read-then-write with no lock, and in `ShipmentService.php:41` it runs *outside* the transaction.

Four routes to negative stock:
- **Concurrency.** Two simultaneous shipments both read 100, both pass, both commit → −100.
- **Duplicate lines in one request — no concurrency needed.** The check loops line-by-line against the same pre-transaction balance and never aggregates by variant. Stock 10, two lines of the same variant at qty 6 → both pass → −2.
- **The check reads a different variant than the write.** `assertSufficientStock` resolves by colour+size and takes `->first()`, ignoring edge; `syncItems` resolves via `findOrCreate` with edge NULL. Different rows.
- **Raw materials have no check at all.** `type: "spent"` for 1000 kg of a material with 0 on hand is accepted unconditionally.

Related: `raw_material_stock_movements.quantity` is a `double`. For kg/m² it should be `decimal(12,3)` — a material that receives 0.1 + 0.2 and spends 0.3 will never report exactly zero.

### STRUCT-3 — `warehouse_received_quantity` silently drops units
**High.** → `phase-1/07`

`creditProductionBatchItems` discards `$remaining` if > 0 after the loop — no exception, no log. Batch item produced 60, warehouse receives 100: ledger +100 → stock 100; credited 60; **40 vanish**. `/stock/variants` then reports `quantity_warehouse: 100` next to `quantity_reserved: 60`, permanently 40 apart.

Credit is FIFO (`orderBy('id')`), debit on reversal is LIFO (`orderByDesc('id')`) → reversing a receipt debits the *wrong batch item*. And `StockController.php:177` wraps the result in `max(0, …)`, clamping away exactly the negative values that would reveal it.

### STRUCT-4 — Every authenticated user can do everything
**High.** Verified directly. → `phase-1/09`

`EnsureRole` is registered in `bootstrap/app.php:17` and applied to **zero routes**. All 26 FormRequests `return true` from `authorize()`. No policies.

It's also broken independently: `2026_05_04_000001` changed `users.role` to JSON and the model casts it to `array`, but the middleware does `in_array($request->user()?->role, $roles, true)` — comparing an array against role strings, always false. Applying it as-is would lock everyone out.

Today a labelling operator's token can delete orders, edit shipment prices, create and delete payments, and delete warehouse documents. With payment hard-delete (LOGIC-5), one compromised device can erase receivables with no trace.

### STRUCT-5 — The audit ledger loses its link to the source document
**Medium.** → `phase-3/06`

`2026_04_13_000003` dropped `warehouse_document_id`, leaving `warehouse_document_item_id` as the *only* link — with `nullOnDelete`. Both `update()` and `delete()` call `$document->items()->delete()`, so the FK nulls out on **both the original and the reversal movements**. The rows survive but become orphans with no traceable source. The reversal's only remaining provenance is free text (`"Reversal of document #42"`) pointing at a row the next line deletes.

Also: `stock_movements.quantity` is a *signed* `integer` despite the comment two lines above promising it's always positive (a negative `out` would silently add stock); `WarehouseDocumentItem::source()` is a `morphTo` against snake_case strings with no `morphMap` registered — it will throw on access.

---

## 04 — Business logic defects

### LOGIC-1 — Deleting a warehouse document can *add* stock
**Critical.** Verified directly. → `phase-0/02`, `phase-0/03`

`reverseMovements()` decides direction from the document's *current* type — but `update()` already persisted the new type:

```php
// update(), line 66 — the new type is written FIRST
$document->update(['type' => $data['type'] ?? $document->type, …]);

// line 74 — the correct value is computed…
$effectiveType = $document->fresh()->type;   // …and never passed down

// reverseMovements(), line 180 — reads the ALREADY-MUTATED type
$originalMovementType = match ($document->type) { … };
```

The reversal direction is a property of *the rows already in the ledger*, not of a mutable column.

1. `POST` document #42, `type: "in"`, qty 100 → ledger `in +100`. Stock = 100.
2. `PATCH /warehouse-documents/42 {"type":"out"}` with no items → the ledger is never touched. The document says *out*; the ledger says *in*.
3. `DELETE /warehouse-documents/42` → reversal reads `out` → decides the original was `out` → writes **another `in +100`**.

Stock = **200** for a deleted document. Expected 0. Silent, permanent.

Step 2 is its own bug: a type-only PATCH is accepted and persisted without reversing or re-issuing movements, and the regenerated PDF renders an *outgoing* document for movements that added stock.

### LOGIC-2 — Editing a warehouse document fails 100% of the time
**Critical.** Verified directly. → `phase-0/04`

`StoreWarehouseDocumentRequest` declares `items.*.product_color_id`. `UpdateWarehouseDocumentRequest` **does not** — but the service reads that key. Laravel's `validated()` strips undeclared array keys, so it's always `null`:

- `PATCH {"type":"out", …}` → stock check reads `null` → no variant → `$currentStock = 0` → always a bogus 422: *"Insufficient stock for 'Product color #' (). Available: 0"*
- `PATCH {"type":"in", …}` → skips the check → `findOrCreate(null, …)` → **TypeError → 500**

Because this path always aborts and rolls back, LOGIC-1's item-replacement branch never executes. **Fix LOGIC-1 first**, or repairing this unmasks the reversal bug.

Also: both requests `require` `items.*.product_id`, which the service never reads — the product is derived through `product_color_id`. Validation theatre.

### LOGIC-3 — Shipment items are never checked against their order, client, or remaining quantity
**Critical.** → `phase-1/02`

`StoreShipmentRequest.php:23` is the only gate and `exists:` is the only check. Nothing verifies the order item belongs to the order, the order belongs to the client, the variant matches, or quantity ≤ unshipped.

- **Wrong client billed.** Order #500 belongs to client B. POST a shipment with `client_id: A`, `order_id: 500`. The debit lands on **A**; B's order is marked *shipped*. B is never invoiced; A is billed for B's goods.
- **Over-shipping.** Order item = 10. Ship 10, ship 10 again. Both succeed, and `ShipmentService.php:457` uses `>=` so it still marks shipped. The client is invoiced for **20** against a **10**-unit order.

`ShipmentImportController` already computes `LEAST(oi.quantity - shipped_qty, sm.stock)` correctly — the logic exists, on a GET endpoint that suggests values, while the POST that writes them enforces nothing.

### LOGIC-4 — The batch state machine has an unreachable state
**High.** Verified directly. → `phase-3/03`

`ProductionBatchService::create()` hard-codes `'status' => STATUS_IN_PROGRESS` and `'started_datetime' => now()`, though the column defaults to `planned`. So `POST /start` (requires `planned`) **can never be called**; `DELETE` (requires `planned`) means **no batch can ever be deleted**; `planned_datetime` is stored but meaningless.

### LOGIC-5 — Payments are hard-deleted; soft-deleted clients' debt disappears
**High.** → `phase-1/06`

`Payment` has no `SoftDeletes` and `PaymentController.php:47` calls `$payment->delete()`. A client who paid $50,000 has that credit erased from summary and ledger, no trail, no way to detect it.

`ClientDebitService::getSummaries` builds on `Client::query()`, which applies the SoftDeletes scope. Soft-delete a client with an outstanding balance and they vanish from the debits report while their shipments — and the receivable — remain.

Also: `getSummaries` INNER JOINs the product tree, so any shipment line with a broken variant chain silently drops out of `total_debit` — under-billing with no error. `getLedger` uses null-safe eager loads and still counts it.

### SCAN-1 — No printed QR label can be scanned
**High.** Verified directly. → `phase-0/11`

`ProductionBatchController.php:321` accepts `/PB\{(\d+)\}\s+PBI\{(\d+)\}/`. The client prints **three formats, none of which match — and which don't match each other**:

| Where | Emits | Example |
|---|---|---|
| `labeling_page.dart:685` — **the real print path** | `'P${item.batchId} I${item.id}'` | `P123 I456` |
| `print_history_page.dart:276` — reprint | `'PB{${item.batchId}} VAR{${item.variantId}}'` | `PB{123} VAR{456}` |
| `labeling_page.dart:480` — preview mock | `'P1 I1'` | `P1 I1` |

Every one returns **400 "Invalid QR code format"**. The scan feature has never worked.

The reprint path is wrong twice over: it encodes **`variantId`**, not `itemId`. Even with the regex fixed it would resolve to the wrong entity whenever the two id sequences collide.

The labels are already glued to carpets and cannot be recalled, so the backend must learn to read `P{batchId} I{itemId}` — not the other way round. The regex is also unanchored, so `JUNK PB{1} PBI{2} JUNK` parses.

### LOGIC-6 — The rest
**Medium / low.** → `phase-0/09`, `phase-3/05`

- **Idempotent document creation is unreachable dead code.** The service checks `external_uuid` for an existing document and returns it — but the request's `Rule::unique(...)` rejects the retry with 422 first. The offline-sync retry path this feature exists to serve is the path it breaks.
- **`adjustment` can only ever increase stock.** `2026_04_30_000001` collapsed it into `in`, with a comment noting the case needed review. A stocktake finding *fewer* carpets — the common case — cannot be entered. Since only `out` is stock-checked, `adjustment` is an unguarded way to mint stock.
- **Two definitions of "incoming".** `WarehouseDocument::isIncoming()` excludes `adjustment`; the `match` in `syncItems` treats it as incoming.
- **Dashboard and analytics can never reconcile.** `production_quantity` counts warehouse `in` document items (including supplier deliveries, not excluding cancelled batches); analytics counts `produced_quantity`. Both labelled "production". 800 woven + 200 bought in = dashboard 1000, analytics 800.
- **`warehouse_stock` ignores its own date range** — nets all movements ever, then is returned next to `date_from`/`date_to`.
- **Unbounded `per_page`** on five endpoints.
- **N+1 everywhere.** `checkAndAutoCompleteOrders` eager-loads `items.productionBatchItems` then ignores it, re-querying per item — 30 orders × 10 items = 300 queries inside the request transaction, holding locks.
- **`%Y-%u` week buckets** mix calendar year with week-of-year; should be `%x-%v`.
- **`array_filter(fn ($v) => $v !== null)`** in three services means `notes: null` can never clear a field.

---

## Verified negatives

Checked and genuinely *not* problems — recorded so they aren't re-investigated:

- **No JOIN fan-out double-counting.** Both analytics `baseQuery()` chains are strictly many-to-one, and every `leftJoin` is onto a PK.
- **No last-day truncation.** Every range predicate is `DATE()`-wrapped and `orders.order_date` is a `DATE` column. The classic `'2026-01-31' = 00:00:00` bug is not present.
- **Timezone is consistent.** `config/app.php:68` sets `Asia/Tashkent`; no connection timezone is set, so Laravel writes and MySQL's `DATE()` reads the same wall-clock strings. No raw `NOW()`/`CURDATE()` in `app/`.
- **No division by zero.** Every percentage is guarded.
- **SQM math is correct.** `product_sizes.length/width` are integer cm, so `SUM(qty * width * length) / 10000` correctly yields m².
- **No float money columns.** Both money columns are `DECIMAL`. `shipment_items.total` was deliberately dropped, so there are no stored totals to drift.
- **Transactions exist.** `ShipmentService::create` and all `OrderService` methods do wrap multi-table writes in `DB::transaction`. PDF/XLSX generation is correctly outside. The gap is the stock *check*, not the writes.
- **Defects are not double-subtracted.** `produced_quantity` and `defect_quantity` are disjoint by design (see PROD-4 for the consequence).

---

## What else

**The absence of tests is the root cause behind the root causes.** `tests/` holds `ExampleTest.php` and nothing else; there's no CI. Both "endpoint completely dead" bugs would have been caught by a single smoke test each. Don't chase coverage — write tests for the stock ledger, the money formula, and a route smoke test. ~40 tests. See `phase-3/01`.

**Two truths that should be one.** See the rule in [README.md](README.md).

**Smaller things worth queuing:** non-sargable `DATE(...)` filters defeating indexes; reversal movements stamped `now()` instead of `document_date`; `getLastPrice` ordering by `created_at` only (bulk imports tie → non-deterministic price); price accepting unlimited decimals then being silently truncated by `decimal(12,2)`; `ShipmentItemResource` emitting `price` as a string while `PaymentResource` emits a number; `APP_ENV=local` in the committed `.env`; `source_type`/`source_id` documented as "enforced at the service layer" and enforced nowhere; an empty batch auto-completing because `$items->every(...)` is true on an empty collection.

## Notes added while writing the step files

Verified during the instruction pass; recorded here so they aren't lost:

- **The variant merge (`phase-1/05`) must repoint five tables, not four.** `warehouse_document_items.product_variant_id` (`2026_04_07_000004:30`) was missed in the first pass. All five are `restrictOnDelete`, so missing one fails the merge part-way through.
- **`ClientDebitService`'s credit subquery uses `DB::table('payments')`**, which a `SoftDeletes` global scope does not reach. Adding the trait to `Payment` (`phase-1/06`) without touching that subquery would silently diverge the debit report from the ledger by the value of every deleted payment.
- **A `production_events` foreign key would break two live paths.** `ProductionBatchService::update()` and `delete()` hard-delete `production_batch_items`, so a default `RESTRICT` starts throwing FK violations on in-progress batches. See `phase-2/01`.
- **`produced_quantity` / `defect_quantity` are `unsignedInteger`** — decrementing past zero throws rather than clamping. Any correction path needs a guard inside the transaction.
- **The test suite can't run as configured.** `config/database.php` defaults to sqlite, but eight migrations use raw MySQL DDL (`MODIFY COLUMN … ENUM`), so `RefreshDatabase` fails at migration time before a single assertion. `phase-3/01` resolves this toward MySQL in CI.
- **OEE is not buildable.** The `machines` table is `id`, `name`, `model_name`, `timestamps` — two of OEE's three factors have no data behind them. `phase-3/08` covers defect rate only, and says why.
- **`printLabel` drives state, not just counts.** `incrementProducedQuantity` (lines 176–180) can auto-complete a batch, so a double-tapped reprint doesn't merely inflate a number — it can close a batch early.
- **The `external_uuid` idempotency plumbing has never run.** The pattern exists server-side in `WarehouseDocumentService` and `OrderService`, but no client call site generates one, and `uuid` isn't in `pubspec.yaml`. It compiles; it has never executed.

## Where to start

1. Fix the dashboard — both bugs, not just the import. Something visibly broken starts working.
2. Run the reconciliation queries **read-only** against production to find out how much stock drift LOGIC-1 and STRUCT-1 have already caused. That number decides how urgent the rest is.
3. Ship phase 0 as a single deploy.

Then `production_events`. It's the change the owner already identified, it's the one that makes the reports honest, and every later phase is easier once the pattern exists in the codebase to copy.
