# Phase 2 — completion report

**Written:** 2026-07-15, at the end of the phase-2 work session, for
handoff into a new session that continues the rollout or starts phase-3.

## Status: code complete for all 8 steps, NOT yet on production, NOT yet on dev

**Phase-0 and phase-1 are also still not on production** (per their own
completion reports) — production (`erp.tgc-carpets.uz`) is running
pre-phase-0 code as of this writing. Phase-2 must not ship ahead of them;
see `instructions/phase-2/DEPLOY.md` "Order relative to phase-0/phase-1".

As in the prior two sessions, nothing here has been run against any
database — no dev, no staging, no production; there is no DB connectivity
in this environment. Every change is verified by `php -l` (all touched/new
PHP files pass), by `dart analyze` (the Flutter client change analyzes
clean, only pre-existing unrelated lint hints), by reading the code against
each instruction file, and by reasoning about behavior — not by executing
it. **Treat this exactly like phase-0 and phase-1's handoff: code
complete, functionally unverified, staging is the mandatory next step**
before any of this touches the live database (see
[[erp-is-live-in-production]]).

## What shipped (code-complete)

| # | Step | Files | Flag / rollout |
|---|---|---|---|
| 01 | `production_events` table + dual-write | migration, `ProductionEvent` model, `ProductionBatchService::incrementProducedQuantity/updateItem`, `DefectDocumentService` | None — purely additive, no existing reader changes |
| 02 | Idempotency key on label print | `ProductionBatchController::printLabel`, `ProductionBatchService`, Flutter: `pubspec.yaml` (`uuid`), labeling bloc/state/repository/datasource | `idempotency_key` nullable — **needs a client release**, no server flag |
| 03 | Backfill opening events | `production:backfill-events` artisan command | One-shot, idempotent, must run in the same maintenance window as step 01's deploy |
| 04 | Repoint analytics at `occurred_at` | `ProductionAnalyticsService` (legacy + events paths side by side), `config/analytics.php`, `/analytics/production/compare` (admin-only) | `ANALYTICS_SOURCE` (default **legacy**) — flip only after showing the owner the compare delta |
| 05 | Defect/scrap as events, fix PROD-4, reversal on delete | `DefectDocumentService` (new), `DefectDocumentController` (now thin), `StoreDefectDocumentRequest` | None — pure relaxation of an over-strict validator, see DEPLOY.md's "Step 05's behavior change" |
| 06 | `production:reconcile` | artisan command, `config/reconcile.php`, `routes/console.php` schedule (02:30) | `--fix` never scheduled; `RECONCILE_SYSTEM_USER_ID` must be set before first use |
| 07 | `product_variant_stock` balance | migration, `ProductVariantStock` model, `ProductVariantStockService`, dual-write in `WarehouseDocumentService` + `ShipmentService`, `stock:backfill-balances` | Dual-write only — **reads NOT switched**; stays on the live SUM until step 08 has run clean for a week (see below) |
| 08 | `stock:reconcile` | artisan command, `routes/console.php` schedule (02:45) | `--fix` never scheduled |

## Deliberately incomplete: step 07's read switch (§6) and the legacy→events flip (step 04)

Both are explicitly **not part of this deploy**, per the instruction
files' own gating:

- `WarehouseDocumentService::getStock()`, `ShipmentService::getStock()`,
  and `StockController`'s correlated subqueries **still read the live
  `SUM(stock_movements)`**. Step 07 §6 requires a week of clean
  `stock:reconcile` output before that switch is safe, and that week
  cannot start until this branch is deployed and the backfill has run.
  This is the same conservative posture phase-1 took with its feature
  flags — ship the cache, prove it, then switch.
- `config('analytics.source')` defaults to `legacy` and stays there until
  a human has looked at `/analytics/production/compare`'s output and
  confirmed it with the owner. No amount of code review substitutes for
  that conversation — the numbers genuinely change, sometimes by a lot,
  and step 04's own instruction file is explicit that shipping the switch
  silently "burns the credibility of every number in the system."

Both are one-line, instantly-reversible flips once their gating condition
is met — see `instructions/phase-2/DEPLOY.md` Stages 5 and 6.

## Judgment calls made without the user present — flag these before deploying

- **`production_events.defect_document_id`:** step 01's own instruction
  file recommends this column but defers it to step 05 as "a nullable
  `defect_document_id` FK... cleanest." Since both steps shipped in the
  same session, it was added directly to step 01's migration
  (`2026_07_15_000004_create_production_events_table.php`) rather than as
  a second migration — one fewer schema change, same result. Flagging in
  case a reviewer looks for it in step 05's diff and doesn't find it there.
- **`updateItem()`'s drift fix (step 06 §5):** the instruction file
  presents three options and says "decide before scheduling." Implemented
  the recommended one — every manual `PATCH .../items/{item}` quantity
  change now writes a `correction`/`defect` event for the delta in the
  same transaction, rather than silently drifting or being rejected
  outright. This was applied in Stage 1 (bundled with step 01) rather than
  waiting for step 06, specifically so the reconcile schedule in Stage 3
  doesn't fire false alarms against this endpoint on day one.
- **Reconcile alerting (`routes/console.php`'s `onFailure()`):** both
  instruction files are emphatic that "a non-zero exit code that goes
  nowhere is not a signal." This session could not confirm what channel
  the team actually reads, so `onFailure()` currently does
  `Log::critical(...)` — a real log entry, but **not yet a finished
  alert**. `config/logging.php` already has a `slack` channel wired to
  `LOG_SLACK_WEBHOOK_URL`, unconfirmed whether that's set on production.
  This is flagged as an explicit, required action in `DEPLOY.md` Stage 3
  — do not consider phase-2 "done" until a human has actually received a
  planted-drift alert.
- **`RECONCILE_SYSTEM_USER_ID` left unset by default:** `production:reconcile
  --fix` refuses to run without it rather than falling back to `users.id =
  1`. This is a deliberate choice to force an explicit decision about who
  manual corrections should be attributed to, not an oversight — set it in
  `.env` before the first `--fix`.
- **`/analytics/production/compare` gated `role:admin`:** phase-1's
  completion report noted that step 09 (broad role-middleware rollout)
  was intentionally dropped from scope at the user's request, and that
  `EnsureRole` shouldn't be resurrected without being asked again. This is
  a narrower, different decision: step 04's own instruction file
  explicitly calls for gating this one new diagnostic route so normal
  roles don't see legacy-vs-event deltas mid-rollout, using the `role`
  middleware alias that already exists in `bootstrap/app.php` (registered,
  unused elsewhere). It does not apply `role:` to any other route. Flagging
  in case this reads as a re-opening of the step-09 decision — it isn't.

## How to verify (staging first, then production per DEPLOY.md)

Follow `instructions/phase-2/DEPLOY.md` stage by stage. Short version:

1. Confirm phase-0 and phase-1 are already deployed to the target
   environment.
2. Run `instructions/phase-2/reconcile-before-deploy.sql` against a
   production copy — query 3 and query 4 are worth showing the owner even
   before deploying anything.
3. Deploy Stage 1 (both migrations + all dual-writes + both new commands,
   unscheduled) and verify against staging using each step's own "How to
   verify" section.
4. Stage 2 — run both backfills in their required windows; verify each
   with the reconcile query in its own instruction file before proceeding.
5. Stage 3 — set `RECONCILE_SYSTEM_USER_ID`, confirm cron is running
   `schedule:run`, wire a real alert, confirm a human receives a planted
   drift alert, **then** trust the nightly schedule.
6. Stage 4 — ship the Flutter release for step 02; track adoption, no rush
   to tighten validation.
7. Stage 5 — once Stage 2/3 have been clean for a few days, pull
   `/analytics/production/compare`, show the owner, get sign-off, flip
   `ANALYTICS_SOURCE=events`.
8. Stage 6 (separate, later session) — after a week of clean
   `stock:reconcile`, switch `getStock()` reads to `product_variant_stock`.

## Handoff notes for whoever continues this

- **Nothing here has touched a real database.** Migrations are believed
  correct by reading and by matching this codebase's existing patterns
  (foreign keys, `cascadeOnDelete`/`nullOnDelete` choices explained inline
  in each migration), but have not been run. Run them on a staging copy of
  production before trusting them.
- **Phase-0 and phase-1 must ship first.** Confirm `erp.tgc-carpets.uz` is
  running their commits before starting `instructions/phase-2/DEPLOY.md`.
- **The core rule still carries forward:** one writer per fact, any cache
  of it gets a reconcile command. This phase is that rule applied twice —
  `production_events`/`production_batch_items` and
  `stock_movements`/`product_variant_stock` — and phase-3's
  `production_units` (deferred, Level 2 of the original audit) and
  `stock_reservations` will be the same shape again.
- **The two reconcile commands are the thing to watch, not the deploy
  itself.** Everything else in this phase is designed to be provably
  correct or trivially reversible; the commands are what turns "believed
  correct" into "known correct." Do not let Stage 3 (wiring a real alert,
  confirming a human receives it) slip — it's the cheapest, highest-leverage
  step in the whole phase and the easiest one to skip under time pressure.
- **Step 07's read switch and step 04's flag flip are the two real
  decision points left**, both deliberately deferred past this session's
  scope — see "Deliberately incomplete" above. Neither needs new code,
  both need a week of clean data first.
- **Level 2 of the original audit (`production_units`, one row per
  physical carpet with a serial in the QR) is explicitly out of scope for
  phase 2** — see [[tgc-erp-audit-2026-07]] and
  `instructions/phase-3/02-production-units-serials.md`. Do not conflate
  it with this phase's `production_events` log; they solve different
  problems.
