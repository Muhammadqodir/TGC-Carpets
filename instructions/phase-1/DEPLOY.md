# Shipping phase 1 to production — safely

The factory is running on this system right now. Unlike phase 0, phase 1 is
**not one bundle** — it mixes pure code changes, a safe additive migration,
one migration that locks a table and rewrites data, and a set of tools that
must categorically not run yet. Deploy it in the stages below, not as a
single `git pull && deploy.sh`.

## Read this first: what changed and what didn't

All nine phase-1 steps from the audit are code-complete except step 09
(role middleware), which was intentionally dropped from this branch — do
not resurrect it as part of this deploy. Step 05 (duplicate variant merge)
is **tooling only**: the commands exist, but merging is a human-reviewed
operation that has not been run, and must not run as a side effect of this
deploy. See `COMPLETION-REPORT.md` for the full step-by-step status.

## Stage A — pure code, no schema change, no flags to flip yet

Steps 01, 02, 03, 04, and 07 (excluding the two log-only pieces described
in Stage C) are code-only:

- No new migration in this stage.
- Step 01 changes money **arithmetic**, not the API shape — `total` and
  `debit`/`credit`/`balance` fields keep the same JSON keys, just
  different values (by a cent or two, for the shipments the reconcile
  query finds).
- Step 03's stock check now runs inside the transaction and takes a
  `lockForUpdate()` on `product_variants` — this can only make a request
  slower under contention or reject a shipment that was already
  impossible, never accept something new.
- Step 04 adds `items.*.product_edge_id` as an **optional, nullable**
  field to both warehouse document requests — existing clients that don't
  send it are unaffected; the server now defaults it to the `R` edge
  server-side instead of leaving it `null`.
- Step 07 unmasks `quantity_reserved` (verified against the Flutter
  client: it renders `value.toString()` with no unsigned assumption, so a
  negative number displays fine, it just looks alarming — which is the
  point).

**Step 02's and 07's stricter validation are off by default** — see Stage D.
Deploying Stage A does not change any accept/reject behavior on its own
except:
- Step 03 will reject a shipment that would have driven stock negative
  (this was already broken; see the reconcile query 3 output first).
- Step 04 stops minting duplicate NULL-edge variants on warehouse
  documents (this is the fix landing, not a new restriction).

### Run first (read-only, no code touched)

```bash
mysql -h <host> -u <readonly-user> -p tgc_carpets < instructions/phase-1/reconcile-before-deploy.sql > /tmp/phase1-reconcile-before.txt
```

Read query 1's output and **tell the office before you deploy**: shipment
ledger/debit figures on those specific shipments will shift by a cent or
two once step 01 ships, to match the invoice PDF rather than the other way
round. Do not regenerate historical PDFs.

### Deploy

```bash
cd tgc_backend
./deploy.sh production
```

Same maintenance-mode dance as phase-0: `php artisan down` → pull → deps →
clear caches → `migrate --force` → rebuild caches → `up`. At this stage
`migrate --force` should find **zero** pending migrations if you haven't
also merged Stage B/C's files yet — keep them on a separate branch/PR if
you want Stage A to ship alone first.

### Verify immediately

1. `GET /api/v1/shipments/{id}` on one of the shipments from reconcile
   query 1 → each item's `total` now equals that query's `per_line`
   column.
2. `GET /api/v1/clients/{client}/debit-ledger` for the same client →
   `summary.total_debit` matches the invoice, not the old ledger figure.
3. Post a shipment with two lines of the same variant that together
   exceed stock → 422, not a negative stock row (`phase-1/03`'s
   verification section has the exact repro).
4. Create a warehouse `in` document for a colour/size that already has an
   `R`-edge variant, **without** sending `product_edge_id` → confirm no
   new variant row appears (`SELECT MAX(id) FROM product_variants`
   before/after).
5. `GET /api/v1/stock` → `quantity_reserved` renders on the client app
   without crashing, including for any variant reconcile query 5
   flagged as already negative.

## Stage B — payments soft-delete (additive migration, safe live)

Ships the `deleted_at` column on `payments`, the `SoftDeletes` trait, and
`ClientDebitService`'s `withTrashed()` + the `whereNull('deleted_at')` fix
on the raw credit subquery (step 06), plus the SQL rounding change to
`getSummaries`'s debit subquery that step 01 also touches — **these two
steps edit adjacent lines of the same method**, already reconciled in this
branch; don't re-merge them separately.

**Run reconcile query 8 first** and tell the office if it's non-empty:
soft-deleted clients with shipment history are about to reappear in
`GET /api/v1/clients/debits` showing their real outstanding balance. This
is correct — the receivable was always real — but it will look like a bug
to whoever deleted that client months ago if nobody warned them.

The migration (`2026_07_15_000001_add_soft_deletes_to_payments_table.php`)
is purely additive and nullable — existing rows get `deleted_at = NULL`,
meaning "not deleted," which is correct for all of them. Safe inside the
same `migrate --force` as any other stage.

Verify: delete a payment via the API, confirm the row still exists with
`deleted_at` set, confirm the debit-ledger and debit-list totals both drop
by the same amount (the one place this step is most likely to ship
broken — see `phase-1/06`'s verification step 3).

## Stage C — raw material `DOUBLE` → `DECIMAL(12,3)` (locks the table)

**Do not bundle this migration's deploy with anything else.** It's a raw
`ALTER TABLE ... MODIFY` that rewrites every row of
`raw_material_stock_movements` and rounds any value with more than 3
decimal places.

1. Run reconcile query 7 against production first. Check the row count —
   if it's large, this needs its own maintenance window, not a quiet
   moment in a bundled deploy.
2. Check the drift: rows where `quantity <> ROUND(quantity, 3)` are
   (almost certainly) float noise being corrected — but look at them,
   don't assume.
3. Deploy the migration alone:
   ```bash
   php artisan migrate --force --path=database/migrations/2026_07_15_000002_convert_raw_material_quantity_to_decimal.php
   ```
4. Verify `SHOW COLUMNS FROM raw_material_stock_movements LIKE 'quantity'`
   reads `decimal(12,3)`, then hit `GET /api/v1/raw-materials/movements`
   and confirm the client renders quantities normally — the model cast
   changed to `decimal:3` (a string internally), but
   `RawMaterialStockMovementResource` casts it back to `(float)` on the
   way out specifically because the Flutter client does
   `(json['quantity'] as num).toDouble()` and would crash on a JSON
   string. This was verified against `tgc_client` in this session; it is
   the single most likely way this stage causes an outage if it ever
   regresses.

This migration's `down()` reverts the column type but **does not undo the
3dp rounding** — treat it as effectively one-way. Take a dump of
`(id, quantity)` before running it if you want a way back.

## Stage D — the rest of step 08 (raw material stock check) and step 07's throw

Both are code already deployed in Stage A/C; what's left is **flipping
their flags**, and that's a config change, not a deploy:

```bash
# after reading a week of logs, see below
RAW_MATERIALS_ENFORCE_STOCK_VALIDATION=true
WAREHOUSE_ENFORCE_ALLOCATION_CHECK=true
SHIPMENTS_ENFORCE_ITEM_VALIDATION=true
```
then `php artisan config:clear` — no deploy, no restart.

## The three feature flags — all default OFF, all log-only until you decide

| Flag | Step | What it gates | Log line to read first |
|---|---|---|---|
| `SHIPMENTS_ENFORCE_ITEM_VALIDATION` | 02 | Rejecting a shipment whose items don't belong to the stated order/client, or that over-ships | `shipment.validation.would_reject` |
| `RAW_MATERIALS_ENFORCE_STOCK_VALIDATION` | 08 | Rejecting a raw-material spend that exceeds the balance | `raw_material.validation.would_reject` |
| `WAREHOUSE_ENFORCE_ALLOCATION_CHECK` | 07 | Rejecting a warehouse `in` document that receives more than production recorded | `warehouse.allocation.would_reject` |

For every flag: deploy with it **off**, let real traffic hit the code path
for at least a week covering a shipping-heavy day, read every distinct log
line and know whether it's a real bug about to be caught or a business
rule the check doesn't understand yet, *then* flip it. Flipping is an env
var change plus `php artisan config:clear` — seconds, no deploy, no
migration. If flipping a flag on causes trouble mid-shift, flip it back
first and diagnose after; these bugs have existed for months, one more day
costs nothing next to a stopped floor.

Reconcile queries 2, 5, and 6 in `reconcile-before-deploy.sql` tell you,
before you even deploy, whether the corresponding flag is likely to be
noisy (many existing rows already violate the rule the flag would start
enforcing) or safe to flip quickly (the query comes back empty).

## Step 05 — variant merge tooling: shipped, deliberately not run

Three artisan commands exist (`variants:find-duplicates`,
`variants:reconcile-skus`, `variants:merge-duplicates`) plus an empty
`product_variant_merges` mapping table. **None of this should be invoked
against production yet.** The migration that creates the mapping table is
additive and safe to include in any stage above. The commands themselves
are dry-run by default and require explicit flags to write anything — see
`COMPLETION-REPORT.md` for exactly what is and isn't safe to do with them,
and why step 04 needs to be verified flat in production for several days
first.

Do **not**, as part of this or any near-term deploy:
- run `variants:reconcile-skus --force`,
- run `variants:merge-duplicates --force`,
- add a migration making `product_edge_id` `NOT NULL`, or
- add the `unique(product_color_id, product_size_id, product_edge_id)`
  constraint.

All four are stage 4/5 of step 05 and depend on stages 1–3 being run
manually, reviewed by a human per duplicate group, and verified clean —
see `instructions/phase-1/05-variant-unique-constraint.md` in full before
touching any of them.

## Rollback

- **Stage A (01–04, 07's report unmask):** pure code, `git revert` + normal
  deploy. Nothing persisted differently that needs undoing — step 03's
  extra lock can only reject, never corrupt; step 04's default edge only
  prevents new duplicates.
- **Stage B (payments soft-delete):** revert the code; **prefer leaving
  the `deleted_at` column** rather than dropping it — it's the only record
  of every soft-delete made while this was live. If you must revert the
  trait while payments were soft-deleted during the window, check
  `phase-1/06`'s rollback note first: a plain code revert re-credits every
  soft-deleted payment.
- **Stage C (raw material decimal):** the column's `down()` reverts the
  type but not the rounding — effectively one-way. Restore from the
  pre-ALTER dump if you need the original float values back.
- **Flags:** instant, env var + `config:clear`, in either direction.
- **Step 05 tooling:** nothing to roll back — nothing has been run.

## Order relative to phase-0

Phase-0 must already be on production before any of this ships — several
phase-1 steps assume phase-0's fixes are live (e.g. step 01 reinstates
`shipments_amount` via the shared formula rather than duplicating it,
which only matters once phase-0/01 has removed the old broken copy). If
phase-0 hasn't been deployed yet, do that first; see
`instructions/phase-0/DEPLOY.md`.
