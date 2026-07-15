# Shipping phase 2 to production — safely

The factory is running on this system right now. Phase 2 is bigger than
phase 0 or 1: two new tables, two new nightly commands, an analytics
rewrite, and a client release. It ships in the stages below, over roughly
the timeline the instruction files estimate (~3 weeks) — not as one
`git pull && deploy.sh`.

**Read this first: phase-0 and phase-1 must already be on production.**
Neither has been deployed yet as of this writing (see their own
`COMPLETION-REPORT.md`). Phase 2's step 05 assumes phase-0's step 05 (the
`defect_quantity` decrement-on-delete fix) is already live — it is, in the
code on this branch, but the *production* database has not had it applied.
Deploy phase-0 and phase-1 first, in that order, before starting here.

## What's additive vs what changes behavior

Everything in this phase falls into one of three buckets:

1. **Purely additive, zero behavior change** — two new tables
   (`production_events`, `product_variant_stock`), the dual-writes into
   them, the `defect_document_id` FK, two new artisan commands not yet
   scheduled. Safe to ship in one deploy.
2. **Behavior change, but a pure relaxation, un-gated** — step 05's
   `StoreDefectDocumentRequest` fix (PROD-4). The old formula could only
   ever *reject* defects on a produced-out item; the new formula is a
   strict superset of what the old one allowed (see "Step 05's behavior
   change" below) — there is no accept-to-reject case, so it ships without
   a flag, same as phase-0/phase-1's bug fixes.
3. **Behavior change, deliberately gated on a human decision** —
   `ANALYTICS_SOURCE` (step 04) and switching stock reads to the balance
   table (step 07 §6). Both wait on a week of clean reconcile output and,
   for step 04, the owner's sign-off after seeing the compare tool.

## Stage 1 — foundation: two additive migrations + dual-writes + commands (unscheduled)

Ships in one deploy:

- `2026_07_15_000004_create_production_events_table.php` — step 01.
- `2026_07_15_000005_create_product_variant_stock_table.php` — step 07.
- `ProductionBatchService::incrementProducedQuantity()` / `updateItem()` —
  dual-write to `production_events`, idempotency-key replay (step 01 + 02
  server side), and `updateItem()` now appends a `correction`/`defect`
  event for any manual quantity change instead of silently drifting
  (step 06 §5's recommended fix, applied up front so the reconcile
  schedule in Stage 3 doesn't fire on day one).
- `DefectDocumentController` → `DefectDocumentService` — defect/scrap
  events, the remainder-first split, the warehouse-write-off boundary, and
  reversal-on-delete (step 05). `StoreDefectDocumentRequest`'s validator
  fix (PROD-4) ships in the same deploy — see below.
- `WarehouseDocumentService` / `ShipmentService` → `ProductVariantStockService`
  — dual-write every `stock_movements` writer into `product_variant_stock`
  (step 07). Nothing reads the new table yet.
- `ProductionAnalyticsService` — both `legacy` and `events` query paths
  exist side by side; `config('analytics.source')` defaults to `legacy`
  (`.env` unset = no behavior change). The `/analytics/production/compare`
  route ships too, gated `role:admin` (step 04).
- `production:reconcile` and `stock:reconcile` commands exist but are
  **not yet scheduled** — that's Stage 3, deliberately after the backfills.

### Step 05's behavior change — read before deploying

The old defect validator computed `remaining = max(0, planned - produced) -
alreadyDefected`. Once `produced == planned` (batch fully labelled),
`remaining` is **always 0** — every defect on a finished carpet was
rejected, unconditionally, regardless of warehouse status. The new formula
adds `scrappableProduced = max(0, produced - warehouse_received)` on top,
so:

- Anything the old code accepted, the new code still accepts (the
  unproduced-remainder term is unchanged, minus using `defect_quantity`
  directly instead of the `defect_document_items` sum the old code used —
  the two agree today because phase-0/05 is live on this branch).
- The new "warehouse write-off boundary" rejection (line: *"allaqachon
  omborga qabul qilingan"*) can only fire in cases the old code **already
  rejected unconditionally** (produced items always had `remaining = 0`
  under the old formula) — so it introduces no new rejection of a
  previously-accepted request.
- What's new is real: a defect on a produced-but-not-yet-warehoused item
  now **succeeds** and **decrements `produced_quantity`** (records a
  `scrap` event) where it previously 422'd. This is the fix — but
  `produced_quantity` is read by the warehouse FIFO credit list, the
  `exclude_warehouse_received` filters, and (once Stage 5 flips the flag)
  analytics. Tell QC and the warehouse desk this is now possible before
  they see a produced count drop after filing a defect on a finished
  carpet — it will be the first time that's ever happened and it is
  correct.

### Run first (read-only, no code touched)

```bash
mysql -h <host> -u <readonly-user> -p tgc_carpets < instructions/phase-2/reconcile-before-deploy.sql > /tmp/phase2-reconcile-before.txt
```

Read query 3 (items currently blocked from any defect) and query 4
(phantom `defect_quantity` from pre-phase-0/05 deletions) — both are
useful context for the owner even before you deploy anything. Query 5
(stock already negative) is the sizing input for Stage 2.

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

`migrate --force` should apply exactly the two migrations listed above —
confirm no others are pending (phase-0/phase-1 should already be applied
from their own deploys).

### Verify immediately

1. Print a label on staging → `production_events` gets one `produced` row,
   `produced_quantity` moves by exactly 1, response body unchanged shape
   (see `instructions/phase-2/01`'s verification steps 3–5).
2. File a defect on a **fully-labelled** batch item → 201, not 422. This is
   the headline fix; reproduce the 422 on the pre-deploy code first if you
   haven't already, so you know the before/after.
3. Delete that defect document → `production_events` gets a reversing
   `defect` row (and a `scrap` reversal if it drew from produced units);
   the original rows are still there, unmutated.
4. Create a warehouse IN/OUT document → `product_variant_stock` gets a row
   for the variant and it moves by the document's quantity. Nothing in the
   stock API response changes (`getStock()` still reads the live SUM).
5. `GET /api/v1/analytics/production` → response identical to pre-deploy
   (source defaults to `legacy`).
6. `GET /api/v1/analytics/production/compare` as a non-admin user → 403.
   As admin → 200 with `legacy`, `events`, and `trend_delta` keys.

## Stage 2 — backfills (maintenance window)

Two independent backfills. Read each instruction file's "ordering trap" /
"race" warning in full before running either on production — both are
about writes racing the backfill's read, not about data loss.

### 2a. `production:backfill-events` (step 03)

**Must run in the same maintenance window as Stage 1's deploy, before any
label is printed against the new code.** If Stage 1 has already been live
for hours or days by the time you get to this, read
`instructions/phase-2/03-backfill-opening-events.md`'s "ordering trap"
section — the naive backfill will double-count whatever was produced in
the gap.

```bash
php artisan production:backfill-events --dry-run     # compare count against reconcile-before query 1
php artisan production:backfill-events               # for real
```

Verify: the reconcile query from `instructions/phase-2/03`'s "How to
verify" #5 returns **zero rows**. If it doesn't, stop — do not proceed to
Stage 3 or Stage 5 on a ledger you know is wrong.

### 2b. `stock:backfill-balances` (step 07)

Prefer running this with writes paused:

```bash
php artisan down
php artisan stock:backfill-balances --dry-run
php artisan stock:backfill-balances
php artisan up
```

If you cannot take a maintenance window, run it live and then immediately
run `php artisan stock:reconcile --fix` to correct anything that raced —
safe only because nothing reads `product_variant_stock` yet (Stage 5b is
the only thing that changes that, and it's weeks away).

Verify: `instructions/phase-2/07`'s "How to verify" #2 query returns zero
rows (balance == ledger for every variant).

## Stage 3 — turn on the alerts

Both reconcile commands exist from Stage 1 but aren't scheduled yet —
scheduling them before the backfills would fire thousands of false alarms
on day one and teach everyone to ignore the alert.

1. Set `RECONCILE_SYSTEM_USER_ID` in `.env` to a real `users.id` — required
   before anyone runs `production:reconcile --fix`; the command refuses to
   fix without it (it will not silently attribute corrections to user #1).
2. Confirm the deploy box actually runs the scheduler:
   ```bash
   crontab -l   # must contain: * * * * * cd /path && php artisan schedule:run >> /dev/null 2>&1
   ```
   If it doesn't, `routes/console.php`'s `Schedule::command(...)` entries
   are decoration. Add the cron entry now.
3. **Wire the alert to a human.** `routes/console.php`'s `onFailure()`
   callbacks currently do `Log::critical(...)` — that is a placeholder, not
   a finished alert. This codebase already has a Slack log channel
   configured (`config/logging.php`, `LOG_SLACK_WEBHOOK_URL`) but it is
   *unconfirmed whether that webhook is actually set on production*. Check
   `.env` for `LOG_SLACK_WEBHOOK_URL`; if it's empty, either set it or
   point `onFailure()` at something else the team reads. Do not consider
   this stage done until a real alert has been received by a human — run
   `php artisan schedule:test --name="production:reconcile"` after
   planting drift on staging and confirm someone actually gets a message.
4. Run both commands manually once, confirm `OK` with the backfills from
   Stage 2 in place:
   ```bash
   php artisan production:reconcile; echo $?   # expect: OK, exit 0
   php artisan stock:reconcile; echo $?        # expect: OK, exit 0
   ```
5. Only then does the `Schedule::command(...)` entries in
   `routes/console.php` start actually running nightly (02:30 / 02:45) —
   they're live from Stage 1's deploy, this step is about making sure they
   fire clean and someone hears about it when they don't.

**`--fix` is never scheduled, on either command, by design.** Drift means
something is broken; a human runs `--fix` after finding the cause. Watch
both for a week before trusting them as the "is phase 2 healthy" signal
for Stages 5 and 6.

## Stage 4 — client release (step 02)

The idempotency key needs a Flutter release; the server has accepted it as
optional since Stage 1.

1. Add the `uuid` package (already in `pubspec.yaml`/`pubspec.lock` on this
   branch) and ship the release through `app_releases`.
2. Track adoption:
   ```sql
   SELECT DATE(occurred_at) AS d,
          SUM(idempotency_key IS NULL) AS legacy_writes,
          SUM(idempotency_key IS NOT NULL) AS keyed_writes
   FROM production_events
   WHERE event_type = 'produced' AND occurred_at >= NOW() - INTERVAL 14 DAY
   GROUP BY d ORDER BY d;
   ```
3. There is no rush to tighten `idempotency_key` from `nullable` to
   `required` — nothing in this deploy does that, and nothing should until
   `legacy_writes` has been zero for a week. That's a future, separate
   change; do not bundle it here.

## Stage 5 — analytics: show the owner, then flip

1. Once Stage 2a's backfill is verified clean and Stage 3's reconcile has
   been green for a few days, pull a real comparison:
   ```bash
   curl "https://<host>/api/v1/analytics/production/compare?from=2026-01-01&to=2026-06-30&trend_by=month" \
     -H "Authorization: Bearer <admin-token>"
   ```
2. **Take `trend_delta` to the owner before flipping anything.** Explain in
   his terms: *"the report was dating your carpets by the last time
   anything touched the record — a warehouse receipt, a defect entry. Some
   months will look different, permanently, once we fix this."* Let him
   confirm against something he trusts.
3. Only after sign-off:
   ```bash
   # .env
   ANALYTICS_SOURCE=events
   ```
   ```bash
   php artisan config:clear && php artisan cache:clear
   ```
   No deploy, no migration — seconds, and instantly reversible by setting
   it back to `legacy` and clearing config/cache again.
4. Leave the `legacy` path in the code for one more release after this,
   then delete it and the compare route along with it — don't leave a dead
   code path that computes wrong numbers as a permanent fixture.

## Stage 6 — NOT part of this deploy: switching stock reads

`WarehouseDocumentService::getStock()`, `ShipmentService::getStock()`, and
`StockController`'s correlated subqueries still read the live `SUM(stock_movements)`
— on purpose. Per `instructions/phase-2/07-product-variant-stock-balance.md`
§6, that switch waits on **a week of clean `stock:reconcile` output**,
which cannot happen before Stage 3 has been running for a week. Come back
to this once that week has passed; it is a small, easily-reverted code
change (revert to the SUM is always correct) once the data has earned the
trust.

## Rollback

- **Stage 1 (schema + dual-writes + code):** revert the code. Both new
  tables are additive and nothing outside phase-2 code reads them —
  `migrate:rollback` drops them cleanly if you also want the schema gone
  (only do this once no code references them). The step 05 validator
  revert restores the PROD-4 bug (defects on finished carpets rejected
  again) — acceptable as an emergency rollback, not as a plan.
- **Stage 2 backfills:** step 03's rows are tagged `reason = 'backfill'` —
  delete by that tag if wrong (`instructions/phase-2/03`'s rollback
  section). Step 07's balances are always safely recomputable by re-running
  `stock:backfill-balances` from the ledger.
- **Stage 3 (schedules):** remove the `Schedule::command(...)` lines from
  `routes/console.php` to stop them; nothing they do (short of `--fix`,
  never scheduled) writes data.
- **Stage 4 (client):** cannot force a client downgrade. Old and new
  clients coexist safely either way — `idempotency_key` stays nullable.
- **Stage 5 (analytics flag):** `ANALYTICS_SOURCE=legacy` +
  `config:clear && cache:clear` — instant, no deploy.
- **Stage 6:** not shipped in this deploy; nothing to roll back.

## Order relative to phase-0/phase-1

Phase-0 and phase-1 must already be on production. Phase-2 step 05 assumes
phase-0/05 (the `defect_quantity` decrement-on-delete fix) is live — if it
isn't, `defect_quantity` may already disagree with
`defect_document_items` before you even start, and reconcile query 4 in
`reconcile-before-deploy.sql` will be noisier than it should be. Deploy
phase-0 then phase-1 first; see their own `DEPLOY.md` files.
