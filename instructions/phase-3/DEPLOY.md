# Shipping phase 3 to production — safely

The factory is still running on this system. Phase 3 is eight mostly-independent
steps rather than one connected mechanism like phase 2 — most of the risk is
concentrated in step 02 (production units) and step 03's schema change, not in
the phase as a whole. Ship in the stages below.

**Read this first: phase-0, phase-1 and phase-2 must already be on
production.** None of the three has been deployed yet as of this writing (see
their own `COMPLETION-REPORT.md`) — production (`erp.tgc-carpets.uz`) is still
running pre-phase-0 code. Phase-3 depends on code from all three (phase-1's
single money formula, phase-2's `production_events`/idempotency key). Deploy
phase-0 → phase-1 → phase-2 first, each via its own `DEPLOY.md`, before
starting here.

## What's additive vs what changes behavior

1. **Purely additive, zero behavior change** — `audit_log` (06),
   `stock_reservations` (07, warn-only, nothing blocks on it), `production_units`
   (02, dual-run alongside the existing counter), the currency/VAT/discount
   columns (04, every default matches current behavior exactly), the new
   `defect_rate`/`by_machine`/`defect_trend` analytics fields (08, additive
   keys on an existing response), the test suite and CI workflow (01).
2. **Behavior change, a pure fix, un-gated** — step 05's adjustment-direction
   fix (adjustments could previously only add stock; the old bug is the
   thing being fixed) and step 03's Path B (a `destroy()` guard that
   rejected every batch that has ever existed, now replaced with a reachable
   rule). Both ship without a flag, same reasoning as prior phases' pure bug
   fixes.
3. **Schema narrowing, needs a pre-flight check** — step 03's migration
   removes `'planned'` from `production_batches.status`'s ENUM. The
   migration itself refuses to run if any row has that status (should be
   impossible; see the migration's own guard), but confirm this on the real
   database before trusting the guard blindly — see "Run first" below.
4. **Deliberately incomplete / gated on a human decision** — the currency
   selector stays hidden in the client (04), stock reservations never hard-block
   an order or shipment in this deploy (07), and `production_units` does not
   become authoritative over `produced_quantity` in this deploy (02, step 5
   of that file's own rollout — needs two clean weeks of
   `production:reconcile-units`). None of these need more code to enable
   later; they need time and a decision.

## Run first (read-only, no code touched)

```bash
mysql -h <host> -u <readonly-user> -p tgc_carpets < instructions/phase-3/reconcile-before-deploy.sql > /tmp/phase3-reconcile-before.txt
```

Read every query's output before deploying anything — several of them are
the actual sizing/decision inputs for later stages (query 1 for step 03's
Path A/B decision, query 4 for step 04's currency sanity check, query 6 for
step 07's backfill preview).

## Stage 1 — foundation: all eight steps' schema + code (one deploy)

Every migration in this stage is either purely additive or backfills to a
value that reproduces current behavior exactly (see "What's additive" above).
Ships together:

- **01** — `tests/Feature/{Smoke,Stock,Money}/*Test.php`, `database/factories/*`,
  `phpunit.xml` (points at a real `tgc_testing` MySQL schema — see the file's
  own "database problem" section), `/.github/workflows/ci.yml`. Touches no
  runtime code.
- **03** — `2026_07_16_000001_drop_planned_status_from_production_batches.php`
  (guarded — see below), `ProductionBatch` (removes `STATUS_PLANNED`),
  `ProductionBatchController::destroy()`/`start()` (start() removed,
  destroy() now allows deleting any non-completed batch with nothing
  produced — `ProductionBatchService::assertNoRecordedProduction()` already
  existed and enforced this; only the unreachable outer guard is gone),
  `ProductionBatchService::start()` removed, the `start` route removed.
  Client: dead `'planned'`-gated UI removed from four files (Start button,
  status chips, filter option, stats card) — all provably dead code since no
  batch has ever been `planned`.
- **05** — `2026_07_16_000002_add_direction_to_warehouse_documents.php`
  (backfills every existing `adjustment` document to `direction='in'`, which
  is what actually happened under the old unconditional mapping),
  `WarehouseDocument::movementType()`/`resolveMovementType()` (single
  definition, replaces the duplicated `match` in
  `WarehouseDocumentService::syncItems()`), the stock-check fix
  (`reducesStock()` now gates adjustments-that-reduce, not just `TYPE_OUT`),
  PDF sign on the total row. `direction` is accepted but **not required** —
  see the file's own note on why (old client compatibility; tighten later).
- **06** — `2026_07_16_000003_create_audit_log_table.php`, `AuditLog` model,
  `AuditableObserver` registered on 12 models in `AppServiceProvider::boot()`,
  `AssignRequestId` middleware (appended to the `api` group),
  `GET /api/v1/audit-log` (admin-only).
- **07** — `2026_07_16_000004_create_stock_reservations_table.php`,
  `StockReservation` model + `StockReservationService`, wired into
  `OrderService` (reserve on every order-item create, release on
  cancellation) and `ShipmentService` (consume on ship). `StockController`
  and `OrderItemResource` gain new, additive `quantity_active_reservations`
  / `quantity_available` fields — the existing (already-honestly-commented)
  `quantity_reserved` field is untouched.
- **08** — `ProductionAnalyticsService` gains `total_defects`/`defect_rate`
  in the summary and every breakdown, a `by_machine` breakdown, and a
  `defect_trend` series dated by `defect_documents.datetime` (legacy source)
  or `production_events.occurred_at` (events source) — never
  `production_batch_items.updated_at`. By-operator is deliberately not
  shipped (see the service's docblock on `buildReport()`). Purely additive
  keys on `GET /api/v1/analytics/production`.
- **04** — `2026_07_16_000005_add_currency_and_vat_to_shipments.php`,
  `2026_07_16_000006_add_discount_to_shipment_items.php`, `config/money.php`,
  `ShipmentItem`/`Shipment`/`Payment` model changes (gross → discount → net
  → VAT → base, computed once and frozen at creation), `ShipmentService`
  stores these on every shipment (defaulting to USD/rate 1/no VAT/no
  discount when the request omits them — every request today), `getLastPrice()`
  gains an optional currency filter, `ClientDebitService`'s SQL subtracts
  `discount_amount` (defaults to 0, byte-identical for existing data; **VAT is
  NOT yet folded into that subquery** — see its inline comment, safe only
  because `vat_rate` is 0 everywhere today). PDF prints the real currency
  symbol and conditional discount/VAT rows. **No client UI ships for any of
  this** — the currency selector and discount/VAT entry stay absent from the
  app entirely; this is backend capability only, reachable today only via
  direct API calls.
- **02** — `2026_07_16_000007_create_production_units_table.php`,
  `ProductionUnit` model, `ProductionBatchService::incrementProducedQuantity()`
  now also mints/reprints a unit serial in the same transaction (dual-run:
  `produced_quantity` keeps incrementing exactly as before),
  `ProductionBatchController::scanItem()` now accepts `TGC-U-\d{8}` **in
  addition to** the existing `P{batchId} I{itemId}` / `PB.. PBI..` formats —
  **correction to that instruction file's own framing: the batch-line format
  is NOT dead, phase-0 already fixed it and it is in active use**, so this is
  additive, not a replacement. `WarehouseDocumentService` accepts an optional
  `serials[]` per receipt line (unused by any client). Two new artisan
  commands, **not yet scheduled**: `production:backfill-units` (Stage 2) and
  `production:reconcile-units` (Stage 3 — already added to
  `routes/console.php` at 02:55 daily; review before trusting, same as
  phase-2's commands). **Client**: `LabelingItemEntity`/`Model` and the
  print-label datasource now carry the returned unit serial, but it is
  **not wired into the printed QR** — see "Deliberately not done" below.

### Step 03's migration — verify before running

```sql
SELECT COUNT(*) FROM production_batches WHERE status = 'planned';  -- must be 0
```

This should be impossible (`ProductionBatchService::create()` has always
forced `in_progress`), and the migration itself refuses to proceed if it
finds a non-zero count (see its `up()`). Still — run it manually first, on
the real database, before trusting an automated guard on a live system.

### Deploy

```bash
cd tgc_backend
php artisan down
git pull
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:clear && php artisan cache:clear
php artisan up
```

Confirm exactly the seven phase-3 migrations apply (`2026_07_16_000001`
through `_000007`) — phase-0/1/2 should already be applied from their own
deploys.

### Verify immediately

1. `DELETE /production-batches/{id}` on a batch with nothing produced → 200,
   row gone. On a batch with one label printed → 422 "cancel it instead", not
   "only planned batches". `POST .../start` → 404 (route gone).
2. Create a warehouse `adjustment` document with `direction: 'out'` on a
   variant with 500 in stock, quantity 20 → balance 480 (this was previously
   impossible — it silently added 20 instead). Reverse it → balance returns
   to 500.
3. Create a `Payment`, delete it → one row in `audit_log` with `event =
   'deleted'` and the full original values (Payment already has SoftDeletes
   from phase-1). `X-Request-Id` header present on the response.
4. Create an order for 80 of a variant with 100 physical stock →
   `stock_reservations` gets one `active` row for 80.
   `GET /api/v1/stock/variants` shows `quantity_active_reservations: 80`,
   `quantity_available: 20`. Ship 80 against it → reservation goes
   `fulfilled`, `quantity_available` unchanged (physical and reserved both
   dropped by 80).
5. `GET /api/v1/analytics/production` → response has the same shape as
   before plus `total_defects`, `defect_rate`, `by_machine`, `defect_trend`
   keys. Existing keys unchanged.
6. Create a shipment with no `currency`/`vat_rate`/discount fields in the
   request (i.e. today's client) → `currency = 'USD'`, `exchange_rate = 1`,
   `vat_rate = 0`, every item's `discount_amount = 0.00`. The hisob-faktura
   PDF is byte-identical to a pre-deploy shipment with the same numbers.
7. Print a label → `production_units` gets one row, `serial` matches
   `TGC-U-\d{8}`, `produced_quantity` still increments exactly as before.
   Reprint (send the returned `serial` back in a second `printLabel` call)
   → `reprint_count` becomes 1, `produced_quantity` unchanged.
   `GET /production-batches-scan?code=TGC-U-00000001` returns full detail.
   `GET /production-batches-scan?code=P1 I1` (the existing format) still
   works exactly as before.

## Stage 2 — one-shot backfill (maintenance window)

**Must run in the same maintenance window as Stage 1's deploy, before any
label is printed against the new code** — same ordering trap phase-2's
`production:backfill-events` has, for the same reason (produced_quantity
already reflecting post-deploy activity would double-count).

```bash
php artisan production:backfill-units --dry-run     # compare against reconcile-before-deploy.sql query 7
php artisan production:backfill-units
```

Verify: `production:reconcile-units` (below) returns clean for every item
that had `produced_quantity > 0` before this ran.

## Stage 3 — turn on the drift report

`production:reconcile-units` is already scheduled in `routes/console.php`
(02:55 daily, after phase-2's two commands) from Stage 1's deploy — this
stage is about confirming it fires clean and someone hears about it when it
doesn't, same as phase-2's Stage 3:

1. Confirm the deploy box runs `schedule:run` via cron (phase-2's DEPLOY.md
   Stage 3 step 2 — already done if phase-2 shipped correctly).
2. Confirm `onFailure()`'s alert channel is real (phase-2's DEPLOY.md Stage 3
   step 3 — same channel, same caveat: `Log::critical` alone is not a
   finished alert).
3. Run manually once: `php artisan production:reconcile-units; echo $?` —
   expect drift to be **non-zero and mostly negative** right after Stage 2's
   backfill (unit_count catching up to produced_quantity is instant from the
   backfill, but any reprint that happened historically is now visible as a
   permanent, correct gap — this is the value of the whole file, not a bug).
   Watch the trend for two weeks; it should stabilize, not grow.

There is no `--fix` for this command — see its own docblock for why
(`produced_quantity` is still the counter of record during the dual-run;
"fixing" it against the unit count would be fixing the trustworthy number to
match the untrustworthy one).

## Stage 4 — audit log: lock the table down

The one irreversible-feeling but easily-undone step. Confirm the actual
application DB user and schema name on the target server first, then:

```sql
REVOKE UPDATE, DELETE ON <schema>.audit_log FROM '<app_user>'@'%';
GRANT INSERT, SELECT ON <schema>.audit_log TO '<app_user>'@'%';
```

If migrations run as the same DB user, they can no longer alter this table
afterward — re-grant temporarily if a schema change is ever needed, then
revoke again. Do this after Stage 1 has been running long enough to trust
the table structure (a day or two), not in the same window as the deploy.

## Stage 5 — client release (optional, low-value alone)

No step in this phase strictly requires a client release — every backend
change in Stage 1 works with the client build already in production. The
only client-visible change is step 03's removal of dead `'planned'`-gated UI
(a Start button and status chip that have never once rendered). Ship it
opportunistically with the next release that has other reasons to go out;
do not cut a release for this alone.

## Deliberately NOT part of this deploy

- **Printing the real unit serial on the label (02, rollout step 4).** The
  backend mints a serial on every print already; the client does not put it
  on the QR yet. Investigating why surfaced a real finding: `labeling_page.dart`'s
  `_onPrint()` renders the label image and sends it to the printer
  **before** the `printLabel` API response (which carries the serial)
  resolves — the network call and the physical print are decoupled today.
  Wiring the serial into the printed QR needs that sequencing reworked
  (await the response, then render) before it's safe to attempt; doing it
  blind risks printing a stale or missing serial on a live shop-floor label.
  Budget this as its own careful piece of work, not a follow-on to this
  deploy.
- **Receiving a warehouse document by scanned serials (02 §5).** The backend
  accepts an optional `serials[]` per line; no client sends it. Needs a
  scanning UI in the receiving flow — new feature, not in scope here.
- **`production_units` becoming authoritative (02, rollout step 5).** Needs
  two clean weeks of Stage 3's reconcile output first.
- **Currency selector / VAT / discount entry in the client (04).** Deliberately
  hidden — see that step's own gating and the legal question on VAT noted in
  `config/money.php`. Needs someone who has actually filed a hisob-faktura to
  confirm the VAT-on-discounted-subtotal assumption before any non-zero
  `vat_rate` is entered anywhere.
- **A hard block on stock reservations (07, rollout step 5).** Deliberately
  unscheduled. Ship visibility (`quantity_available` in the API, done in
  Stage 1), let the warehouse see the numbers for a month, decide with them
  whether a block is wanted.
- **By-operator defect breakdown (08).** Blocked on `responsible_employee_id`
  meaning "who ran the loom" rather than "who typed the batch in" — that
  needs Path A of step 03, which this deploy did not take (see
  `COMPLETION-REPORT.md` for the Path A/B decision and why).

## Rollback

- **Stage 1:** revert the code. Every migration in this stage is additive or
  backfills to a value matching current behavior — `migrate:rollback` is
  safe *only* while no `direction='out'` adjustment and no `planned` batch
  exist (neither can, immediately post-deploy). Once a `direction='out'`
  adjustment exists, reverting the code makes old code read it as `in` —
  see `05-signed-adjustment-documents.md`'s own rollback section for the
  find-and-reverse-first procedure.
- **Stage 2 (backfill):** `production_units` rows from the backfill are
  tagged `backfilled_at IS NOT NULL` — delete by that tag if wrong, same
  shape as phase-2's `reason = 'backfill'` tagging.
- **Stage 3 (schedule):** remove the `Schedule::command('production:reconcile-units')`
  block from `routes/console.php`; it never writes data (no `--fix` exists).
- **Stage 4 (grant):** re-grant `UPDATE, DELETE` to the app user if this
  needs to be undone — but ask why first; the grant existing is the entire
  point of step 06.
- **Stage 5:** nothing to roll back; it's dead-code removal.

## Order relative to phase-0/phase-1/phase-2

All three must already be on production before this. Phase-3 step 02 assumes
phase-2's `production_events`/idempotency-key work is live (the same
transaction now does both). Phase-3 step 04 assumes phase-1's single money
formula (`ShipmentItem::lineTotal()`) already exists — it does, on this
branch, and this phase extends it rather than replacing it.
