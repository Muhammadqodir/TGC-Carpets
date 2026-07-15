# Shipping phase 0 to production — safely

The factory is running on this system right now. This is the runbook for
pushing the phase-0 fixes live without downtime, without breaking an
in-progress shift, and without touching data you can't put back.

## Why this batch is low-risk

Every phase-0 change is **code-only** — no new migration, no dropped or
renamed column, no changed API contract for existing callers:

- No `database/migrations/*` files were added or changed. `php artisan
  migrate --force` in `deploy.sh` will find nothing new to run.
- The dashboard fix *removes* one JSON key (`shipments_amount`) that no
  screen in `tgc_client` reads (verified: `grep -r shipments_amount
  tgc_client/lib` returns nothing).
- The QR-scan backend fix only **widens** the accepted format — it still
  accepts everything it accepted before, plus the format the client
  actually prints. Nothing that worked before stops working.
- The two Flutter changes (`labeling_page.dart`, `print_history_page.dart`)
  only affect local, on-device print history (`SharedPreferences`) and the
  QR payload baked into a printed/reprinted label image. They read old,
  differently-shaped history entries safely (`itemId` is nullable and
  defaults to `null` via `fromJson`) — installing the new app build does
  not require clearing app data or touching the server.
- `per_page` capping only rejects requests that were already dangerous
  (`?per_page=1000000`); every existing client default (30 or 50, verified
  by grep) is far under the new 200 cap.

So this batch does **not** need the full expand → dual-write → backfill →
switch-reads → contract dance — that's for phase-1/phase-2 changes that
touch schema. It does still need the two things that always apply on a
live system with no tests: **measure first, and roll out in a way you can
undo.**

## Step 1 — measure the existing damage (read-only, before touching code)

Run every query in [`reconcile-before-deploy.sql`](reconcile-before-deploy.sql)
against production — a read replica if you have one, otherwise directly,
since they are pure `SELECT`s with no locking risk. Save the output.

```bash
mysql -h <host> -u <readonly-user> -p tgc_carpets < instructions/phase-0/reconcile-before-deploy.sql > /tmp/reconcile-before.txt
```

This tells you, before you deploy anything:
- how many units of phantom stock the reversal bug (LOGIC-1) already added
- which warehouse documents already disagree with their own ledger
- which batch items have a stale `defect_quantity`
- which batches may have auto-completed early, short-changing an order
- how many QR-labelled carpets already point at deleted batch items

**Do not auto-correct anything this query finds.** Save the numbers, hand
them to the owner, and let a human decide what (if anything) to fix in the
data. The code changes below stop the bleeding; they don't rewrite history.

## Step 2 — deploy the backend as one release

All eleven phase-0 backend fixes are already bundled as a single set of
changes (this is intentional — see "Order of operations that actually
matters" in `instructions/README.md`: `phase-0/02` must land no later than
`phase-0/04` in the same deploy, or the endpoint briefly becomes a live
corruption path instead of a dead one). Deploying them piecemeal is the
one thing that would actually make this riskier than doing nothing.

```bash
cd tgc_backend
./deploy.sh production
```

`deploy.sh` already does the right things for a live system:
- `php artisan down` before touching anything, `up` on exit (even on
  failure, via the `trap cleanup EXIT`) — the app shows a maintenance page
  instead of throwing 500s mid-deploy.
- `git pull`, `composer install --no-dev`, cache clear → `migrate --force`
  → cache rebuild, in that order, so cached config/routes never point at
  code that hasn't landed yet.
- Health check at the end (DB connectivity, storage symlink).

**Maintenance-mode window.** `php artisan down` blocks every request,
including from the Flutter app on the factory floor, for the few minutes
the script runs. Deploy during a natural lull (start/end of shift, lunch)
rather than mid-production if you can — printing labels or scanning a
carpet mid-`composer install` will just queue up as a failed request the
operator retries, not lose data, but it's a bad few minutes for them.

If your production host doesn't run `deploy.sh` directly (e.g. a managed
PaaS), replicate the same order by hand: maintenance mode on → pull → deps
→ clear caches → migrate → rebuild caches → maintenance mode off. Skipping
the "clear caches before migrate" step is the classic way to have Laravel
serve a stale `config:cache` against a new schema.

## Step 3 — verify against the live system immediately after

There is no test suite, so this is the only safety net. Do these in the
first five minutes, before you consider the deploy done:

1. `GET /api/v1/dashboard/stats` returns 200, not 500 (phase-0/01).
2. Open the Flutter dashboard screen and confirm it renders.
3. `PATCH` a real warehouse document with `{"type":"out"}` and no `items`
   → expect 422 with the Uzbek message, not a silent 200 (phase-0/03).
4. Create → delete a small `in` warehouse document for a low-traffic
   variant; confirm stock returns to its starting value, not
   starting + 200 (phase-0/02). Use a variant nobody else is touching.
5. Scan one real, physically-printed QR label with the Flutter app →
   expect the item to resolve, not a 400 (phase-0/11).
6. Tail the log for the first hour: `tail -f storage/logs/laravel.log` —
   watch specifically for the `defect_quantity decrement skipped` warning
   (phase-0/05), which means a defect document was deleted against an
   already-drifted counter and tells you the reconciliation query in step 1
   undercounted.

If step 3 or 4 fails, you're in the reversal-direction code path — stop
and re-check `reverseMovements()` before doing anything else on
warehouse documents.

## Step 4 — the Flutter client is a separate, un-coordinated release

Nothing in Step 2 requires the client to be updated at the same time, or
at all, right away:

- The backend QR regex now accepts both the old client format (`P123
  I456`) and the documented one (`PB{123} PBI{456}`) — today's installed
  app keeps working unchanged the moment the backend deploys.
- The `print_history_page.dart` / `labeling_page.dart` fix only matters
  once operators are printing/reprinting new labels — ship it on your
  normal app-release cadence, no server coordination needed.

When you do build and roll out the client update:

```bash
cd tgc_client
flutter build apk --release   # or your usual release target(s)
```

- **Don't force-update everyone at once** if the factory has devices on
  spotty Wi-Fi — a staged rollout (if your distribution channel supports
  it) means a bad build affects a few phones, not every operator on shift.
- After rollout, the *first* new print/reprint after the update writes a
  `PrintHistoryEntity` with a real `itemId`. Older entries already in a
  device's local history keep the pre-fix behavior (harmless — QR reprints
  from those specific old entries just won't scan, exactly like every
  reprint fails today) and age out automatically (history caps at 30
  items). No app-data wipe or backend coordination needed for this.

## Step 5 — measure again, and watch for one thing specifically

Re-run `reconcile-before-deploy.sql` a day or two after the deploy.
Queries 1–4 should **stop growing** (existing corrupted rows from before
the fix will still show up — that's expected, this batch doesn't repair
history) even though they don't go to zero. If any of them keeps growing
after the deploy, one of the fixes didn't take, or there's a fifth code
path nobody found — treat that as a rollback trigger.

## Rollback

Every fix in this batch is a straight code revert with **nothing to undo
in the database** — none of the phase-0 changes write data differently in
a way that needs correcting on rollback (the reversal-direction fix
writes *fewer*, more correct movements; the defect-quantity fix
decrements a counter that was already wrong):

```bash
cd tgc_backend
git revert <deploy-commit-sha>
./deploy.sh production
```

The one exception to watch: if you already deleted a warehouse document
*after* deploying phase-0/02, that deletion wrote a correct one-line net
reversal instead of the old buggy full mirror. Reverting the code doesn't
un-write that row, and it shouldn't — it was correct. Don't "fix" it back.

For the client, rollback is whatever your distribution channel supports
(re-publish the previous build). There's no data migration to reverse —
`itemId` being absent on old history entries is already the documented,
handled case.
