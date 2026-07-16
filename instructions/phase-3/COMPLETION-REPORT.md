# Phase 3 — completion report

**Written:** 2026-07-16, at the end of the phase-3 work session, for
handoff into a new session that continues the rollout.

## Status: code complete for all 8 steps, NOT yet on production, NOT yet on dev's predecessor phases either

**Phase-0, phase-1 and phase-2 are also still not on production** (per their
own completion reports) — production (`erp.tgc-carpets.uz`) is running
pre-phase-0 code as of this writing. Phase-3 must not ship ahead of them; see
`instructions/phase-3/DEPLOY.md` "Order relative to phase-0/phase-1/phase-2".

As in the three prior sessions, nothing here has been run against any
database — no dev, no staging, no production; there is no DB connectivity in
this environment (confirmed again at the start of this session: `SQLSTATE[HY000]
[2002] Connection refused` against the configured `127.0.0.1:8889`). Every
change is verified by `php -l` (all 123 touched/new PHP files pass), by
`dart analyze` (zero errors across the whole Flutter client, only pre-existing
style infos/warnings), by reading the code against each instruction file, and
by reasoning about behavior — not by executing it. **Treat this exactly like
phase-0/1/2's handoff: code complete, functionally unverified, staging is the
mandatory next step** before any of this touches the live database (see
[[erp-is-live-in-production]]).

## What shipped (code-complete)

| # | Step | Files | Flag / rollout |
|---|---|---|---|
| 01 | Tests + CI | `tests/Feature/{Smoke,Stock,Money}/*`, `database/factories/*` (10 new + 2 model trait additions), `phpunit.xml` (MySQL, not sqlite), `/.github/workflows/ci.yml` | None — additive files, touches no runtime code |
| 03 | Fix batch state machine | `2026_07_16_000001_...` (drops `'planned'` from the ENUM, guarded), `ProductionBatch`, `ProductionBatchController`/`Service`, routes, 6 Flutter files | **Path B taken by default** (no DB access to run the empirical query) — see below |
| 05 | Signed adjustment documents | `2026_07_16_000002_...` (`direction` column), `WarehouseDocument::movementType()`, `WarehouseDocumentService`, both Store/Update requests, PDF | `direction` accepted but not required — old client (which cannot create adjustments at all today — see below) unaffected either way |
| 06 | Audit log | `2026_07_16_000003_...` (`audit_log` table), `AuditLog`, `AuditableObserver` (12 models), `AssignRequestId` middleware, `AuditLogController` | None — additive; the `REVOKE`/`GRANT` DB lockdown is a separate manual DEPLOY.md Stage 4 action |
| 08 | Defect rate / yield metrics | `ProductionAnalyticsService` (defect_rate, by_machine, defect_trend), `ProductionAnalyticsResource` | None — additive keys on an existing response |
| 07 | Stock reservations | `2026_07_16_000004_...` (`stock_reservations` table), `StockReservation`, `StockReservationService`, wired into `OrderService`/`ShipmentService`, additive fields on `StockController`/`OrderItemResource` | Warn-only — nothing blocks an order or shipment in this deploy |
| 04 | Currency/VAT/discount | `2026_07_16_000005_...`, `2026_07_16_000006_...`, `config/money.php`, `ShipmentItem`/`Shipment`/`Payment` models, `ShipmentService`, `ClientDebitService`, both Shipment resources, PDF | Every default reproduces current behavior exactly; **no client UI ships** — see below |
| 02 | Production units and serials | `2026_07_16_000007_...` (`production_units` table), `ProductionUnit`, `ProductionBatchService::incrementProducedQuantity()` (dual-write), `scanItem()` (dual-format), `WarehouseDocumentService` (optional serials), `production:backfill-units`, `production:reconcile-units` (scheduled, unfixable), Flutter: `LabelingItemEntity`/`Model`/datasource carry the serial | Dual-run — `produced_quantity` stays authoritative; unit-serial printing NOT wired into the client (see below) |

## A finding that changes how to read the phase-3 instruction files

**The phase-3 instruction files were written against the 14 July audit,
before phase-0/1/2 landed on this branch.** Two of their central "why this
matters" claims are now stale, discovered while implementing this session:

- **02's framing that the QR scan endpoint is dead in production is no
  longer true.** Phase-0 step 11 already fixed `scanItem()` to accept both
  `P{batchId} I{itemId}` and `PB{batchId} PBI{itemId}`, and both are in
  active use by the client. This session's serial format
  (`TGC-U-\d{8}`) was added **alongside** the existing formats, not as a
  replacement — the instruction file's "do not write a compatibility parser"
  advice does not apply; there is an installed base of scannable labels now.
- **01's two headline "dead endpoint" examples (Dashboard 500, warehouse
  update failure) are also already fixed** by phase-0. The test suite in
  this session still asserts them because a regression test should outlive
  the bug it was written for, but do not read the test file's docblock as
  describing current production behavior.

Flagging this so a reviewer doesn't spend time reconciling the instruction
files' narrative against code that has already moved past it — the code in
this session accounts for the drift; the instruction files themselves were
not edited to match (per `instructions/README.md`, they're a record of the
original findings, not a changelog).

## The step 03 Path A/B decision — made without the user present

The instruction file is explicit: *"Ask the factory one question: do you
ever create a batch that is not started immediately?"* and gives a SQL query
to run empirically. **This session had no database connectivity and could not
run it.** Per the instruction file's own fallback — *"Default to Path B if
the answer is ambiguous... maintaining a state machine nobody uses is a
permanent tax"* — this session took **Path B**: deleted the unreachable
`'planned'` status rather than building real scheduling.

**Run query 1 in `reconcile-before-deploy.sql` before deploying this.** If
`genuinely_scheduled_ahead` turns out to be material, this decision was
wrong and step 03 needs redoing as Path A before shipping — the migration
has not run anywhere, so nothing is lost by revisiting it now.

A useful side effect of Path B: `ProductionBatchService::assertNoRecordedProduction()`
already existed (added for `update()`'s item-replace guard) and already
implements the correct deletion rule. The old `destroy()` bug wasn't a
missing feature, it was a redundant, wrong outer guard (`status !== 'planned'`)
shadowing a correct one — the fix is three lines in the controller, not new
service logic.

## Judgment calls made without the user present — flag these before deploying

- **`direction` (step 05) and `currency`/`vat_rate`/discount fields (step 04)
  were deliberately NOT made required**, even though each instruction file's
  first-pass example code makes them so. Both files' own "How to verify" /
  rollout sections flag the tension (old client compatibility) and recommend
  the conservative default; this session took that recommendation rather
  than the first-pass example. Tighten to required only after confirming
  client adoption — there is no client that sends either field yet (see
  next point).
- **Investigating step 05 surfaced that the Flutter client has NO UI to
  create `adjustment` or `return` type warehouse documents at all** — the
  only creation flow (`add_warehouse_document_page.dart`) is hardcoded to
  `type: 'in'`. This means the direction fix is currently reachable only via
  direct API calls, which makes the "old client compatibility" concern above
  moot in practice (there is no old client behavior to preserve for
  adjustments specifically) but also means **the fix has no visible effect
  in the app until someone builds an adjustment-creation screen** — a real,
  separate, unscoped feature. Flagging so this isn't mistaken for "shipped
  and usable."
- **Step 02's unit serial is NOT printed on the label in this deploy**,
  despite the backend fully minting one on every print. Investigating the
  client print flow found that `labeling_page.dart`'s `_onPrint()` renders
  the label image and sends it to the printer **before** the API response
  (which carries the serial) resolves — an existing optimistic-render
  design, unrelated to this phase. Wiring the serial into the printed QR at
  the current call site would risk printing a stale or missing serial on a
  live label; this needs the print sequencing reworked (await the response,
  then render) as its own careful piece of work. The entity/model/datasource
  plumbing to carry the serial was built and left in place (inert, additive)
  so that future work doesn't have to redo it.
- **Step 08's by-machine breakdown ships; by-operator does not**, per the
  instruction file's own gate — `responsible_employee_id` is the batch's
  *creator*, not necessarily who ran the loom, and Path B (above) did not
  add a `start()` step that would set it correctly. Revisit if a future
  session takes Path A for step 03.
- **Step 08's per-dimension breakdowns (by_type, by_color, by_size,
  by_quality, by_edge, by_machine) only show defects for a dimension value
  that ALSO has produced output in the period.** A batch line with defects
  but zero production is invisible in those breakdowns (though correctly
  counted in the top-level `summary.total_defects`) because the row set
  comes from the produced-side query. A proper fix needs a full outer join
  between the produced and defect queries; deferred as a documented,
  bounded gap rather than risking a rushed rewrite of five query methods.
- **`ClientDebitService`'s SQL subtracts `discount_amount` per line but does
  NOT add `vat_amount`.** VAT is a per-shipment figure; the subquery
  aggregates at the line level, so naively summing `vat_amount` there would
  multiply-count it once per line on any multi-line shipment. Safe today
  only because `vat_rate` is 0 everywhere (no client sets it) — flagged
  in-line in the code and here so it is not missed if step 04's VAT is ever
  actually turned on before this is fixed properly (needs a shipment-level
  pre-aggregation, a bigger change than this pass).
- **The idempotency-key-replay case in `incrementProducedQuantity()` returns
  a null unit.** If a client retries a print-label call with the same
  idempotency key after never seeing the original response, the retry's
  response cannot recover the serial minted on the first, successful attempt
  — there is no lookup path from idempotency_key back to the unit row.
  Accepted rather than adding a second indexed column for a genuinely rare
  case (the client only retries after a network failure with no response at
  all, which usually means the original request never reached the server
  either); documented in the method's own docblock.
- **`AuditLogController` is gated `role:admin`**, the same narrow,
  already-established exception phase-2 used for
  `/analytics/production/compare` — not a re-opening of phase-1 step 09
  (broad role-middleware rollout, dropped from scope at the user's explicit
  request). Applies `role:` to these two routes only.

## How to verify (staging first, then production per DEPLOY.md)

Follow `instructions/phase-3/DEPLOY.md` stage by stage. Short version:

1. Confirm phase-0, phase-1 and phase-2 are already deployed to the target
   environment.
2. Run `instructions/phase-3/reconcile-before-deploy.sql` — query 1 is the
   Path A/B decision input (re-litigate step 03 if it disagrees with Path
   B), query 2 is the migration's own safety guard, query 4 is the currency
   sanity check that must pass before trusting the `USD` backfill default.
3. Deploy Stage 1 (all seven migrations + all code, unscheduled backfill/
   reconcile commands) and verify against staging using each step's own "How
   to verify" section plus `DEPLOY.md`'s consolidated checklist.
4. Stage 2 — run `production:backfill-units` in the required maintenance
   window; verify with query 7 (commented out, becomes runnable post-backfill).
5. Stage 3 — confirm the nightly `production:reconcile-units` schedule fires
   and someone receives the alert (same alert-channel caveat as phase-2).
6. Stage 4 — apply the `audit_log` `REVOKE`/`GRANT`.
7. Stage 5 (optional) — ship the client release for step 03's dead-code
   removal; nothing else needs one.

## Handoff notes for whoever continues this

- **Nothing here has touched a real database.** Migrations are believed
  correct by reading and by matching this codebase's existing patterns, but
  have not been run. Run them on a staging copy of production before
  trusting them — this is the fourth session in a row to write this
  sentence; staging is not optional at this point.
- **Phase-0, phase-1 and phase-2 must ship first.** Confirm
  `erp.tgc-carpets.uz` is running their commits before starting
  `instructions/phase-3/DEPLOY.md`.
- **The core rule still carries forward:** one writer per fact, any cache of
  it gets a reconcile command. This phase adds two more instances of it —
  `production_units`/`produced_quantity` and `stock_reservations` alongside
  (not replacing) `stock_movements` — and leaves `production_units` in the
  same "prove it, then switch" posture phase-2 used for
  `product_variant_stock`.
- **Three real product decisions are now sitting in front of the user,**
  not just deploy mechanics: (1) confirm or overturn the step 03 Path A/B
  call using query 1 once there's DB access; (2) decide whether an
  adjustment-creation screen is worth building, now that step 05's backend
  fix has no client surface to attach to; (3) decide who does the print-flow
  rework needed before step 02's serial can actually go on a label — this is
  real engineering work, not a flag flip.
- **Phase-3 is described in `instructions/README.md` as "ongoing"** — unlike
  phases 0-2, there is no phase-4 waiting behind it. Once this deploys and
  settles, the next work is either the deferred items above or a fresh audit.
