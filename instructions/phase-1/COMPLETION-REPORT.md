# Phase 1 — completion report

**Written:** 2026-07-15, at the end of the phase-1 work session, for handoff
into a new session starting phase-2 (or finishing step 05).

## Status: code complete for 8 of 9 steps, NOT yet on production, NOT yet on dev

**Phase-0 is also still not on production** (per its own completion report)
— production (`erp.tgc-carpets.uz`) is running pre-phase-0 code as of this
writing. Phase-1 must not ship ahead of phase-0; see
`instructions/phase-1/DEPLOY.md` "Order relative to phase-0".

Nothing in this session has been run against any database — not dev, not
staging, not production. There is no local DB connection available in this
environment (`.env` points at `127.0.0.1:8889`, connection refused from
here), so every change below is verified by `php -l`, by reading the code
against the instruction files, and by reasoning about behavior — not by
executing it. **Treat this the same way phase-0 was handed off: code
complete, functionally unverified, staging is the next required step.**

## Step 09 — intentionally skipped

The user removed `instructions/phase-1/09-apply-role-middleware.md` from
the branch during this session and asked for it not to be done. `EnsureRole`
middleware, `bootstrap/app.php`'s `role` alias, and `routes/api.php` are
untouched. If step 09 is wanted later, it needs its own instruction file
restored and its own 2-week production-log audit — nothing here assumes or
depends on it.

## What shipped (code-complete)

| # | Step | Files | Flag / rollout |
|---|---|---|---|
| 01 | Single money formula | `ShipmentItem::lineTotal()`, `ShipmentItemResource`, `ClientDebitService` (ledger + summaries SQL), `shipment_hisob_faktura.blade.php` | None — pure formula fix, ships as-is |
| 02 | Validate shipment items against order | `StoreShipmentRequest::withValidator()`, `config/shipments.php` | `SHIPMENTS_ENFORCE_ITEM_VALIDATION` (default **false** — log-only) |
| 03 | Stock check inside transaction, accumulated, locked | `ShipmentService::create/assertSufficientStock` | None — always active, can only reject what was already impossible |
| 04 | Pass `product_edge_id` in `WarehouseDocumentService` | `syncItems`, `assertSufficientStock`, both warehouse-document requests | None — server-side default to `R` edge when client omits it (confirmed via `tgc_client` grep: it does) |
| 06 | Payment soft-deletes + `withTrashed()` clients | `Payment` model + migration, `ClientDebitController`, `ClientDebitService`, `ClientDebitSummaryResource` | None — additive migration, always active |
| 07 | Symmetric FIFO + unmask `quantity_reserved` | `WarehouseDocumentService::credit/debitProductionBatchItems`, `StockController`, `config/warehouse.php` | `WAREHOUSE_ENFORCE_ALLOCATION_CHECK` (default **false** — log-only) |
| 08 | Raw material stock check, decimal type, clean delete | `RawMaterialStockService`, `StoreBatchMovementRequest`, migration, `RawMaterialStockMovement` model, `RawMaterialStockMovementResource`, `RawMaterialController::destroy`, `config/raw_materials.php` | `RAW_MATERIALS_ENFORCE_STOCK_VALIDATION` (default **false** — log-only) |
| 05 | Variant-merge tooling | `product_variant_merges` migration, three artisan commands | **Not run.** See below — this is tooling, not a completed fix. |

All three new feature flags default to `false` in both `config/*.php` and
`.env.example` — deploying this branch changes zero accept/reject behavior
for steps 02, 07's throw, and 08's validation until someone deliberately
flips a flag after reading a week of logs, per each step's own file and
`instructions/phase-1/DEPLOY.md`.

## Step 05 — why it's tooling, not a fix

`instructions/phase-1/05-variant-unique-constraint.md` is explicit that
this step:
- depends on step 04 being deployed and the duplicate count verified flat
  in production **for several days** before stage 1 (SKU reconciliation)
  even starts,
- needs a human, in writing, to decide per duplicate group whether it's
  one carpet or two different products,
- needs a full `mysqldump` taken and restore-tested before stage 3 (the
  merge) touches anything, and
- needs stages 4–5 (making `product_edge_id NOT NULL` and adding the real
  unique constraint) to happen only after 1–3 are clean.

None of that can happen in this session — step 04 hasn't even been
deployed yet, let alone watched for several days. So what shipped is:

- `database/migrations/2026_07_15_000003_create_product_variant_merges_table.php`
  — the mapping/forensic table, empty, additive, safe to deploy any time.
- `php artisan variants:find-duplicates` — read-only, reports the
  duplicate groups exactly as the instruction file's stage-2 queries
  describe. Safe to run against production today, right now, for
  information.
- `php artisan variants:reconcile-skus [--force]` — stage 1. Dry-run by
  default; reports which variants' `sku_code` would change under the
  current `generateSku()` and, critically, which would **collide** (the
  actual duplicate signal). `--force` only rewrites non-colliding rows;
  colliding groups are left untouched and printed for the merge step.
- `php artisan variants:merge-duplicates --group=<ids> --reason="..." [--force]`
  — stage 3. Merges exactly one human-specified group per invocation,
  never discovers or decides groups itself, defaults to dry-run, and
  refuses to write without an explicit `--reason`. It also warns if a
  loser variant holds a `barcode_value` (a possible printed physical
  label) before deleting it, and verifies the summed stock across the
  group is unchanged after the merge — throwing and rolling back if not.

**Explicitly not done:** no `NOT NULL` migration on `product_edge_id`, no
`unique(product_color_id, product_size_id, product_edge_id)` constraint.
Adding either before stages 1–3 are complete would, per the instruction
file, either fail outright or start throwing `UniqueConstraintViolation`
on legitimate warehouse documents in production. These are the next
concrete action once step 04 has been live for "several days" with a flat
duplicate count.

## Judgment calls made without the user present — flag these before deploying

- **Step 04's edge default:** confirmed via `grep` that
  `tgc_client`'s `WarehouseDocumentItemEntity`/`.toJson()` never sends
  `product_edge_id`. Per the instruction file's explicit branching on this
  fact, the server now defaults to the `R` edge (the one every existing
  variant was backfilled to) rather than `null`. This is the instructed
  behavior for this exact situation, not an improvised guess — but it's
  still worth the office confirming that `R` (rectangular) is in fact the
  correct default for warehouse-received goods with no specified edge.
- **Step 07's throw:** the instruction file recommends a direct
  `ValidationException` with a caveat to check production data first. Since
  this session has no database access to run that check, the throw was
  instead gated behind `WAREHOUSE_ENFORCE_ALLOCATION_CHECK` (default off,
  log-only) — the same pattern as steps 02 and 08 — rather than shipping it
  live and hoping reconcile query 5 turns out clean. This is more
  conservative than the instruction file's literal text; flip the flag only
  after reading a week of `warehouse.allocation.would_reject` logs.
- **Step 06's zero-balance deleted clients:** the instruction file offers a
  choice ("decide with the office") between always showing deleted clients
  or only showing ones with an outstanding balance. Implemented the
  latter as the default (`include_deleted` filter, off by default) since
  the file itself calls it "the sensible default" — but this was not
  confirmed with the office and should be before relying on it.

## How to verify (staging first, then production per DEPLOY.md)

Follow `instructions/phase-1/DEPLOY.md` stage by stage. It has the full
verification checklist per stage; the short version:

1. Run `instructions/phase-1/reconcile-before-deploy.sql` against a
   production copy first — every query maps to one of the judgment calls
   or flag decisions above.
2. Deploy Stage A (01–04, 07's unmask) and verify against staging using
   each step's own "How to verify" section.
3. Deploy Stage B (payments soft-delete) — check the divergence between
   the debit-list and the ledger explicitly; it's the failure mode the
   step is most likely to ship with.
4. Deploy Stage C (raw material decimal) in its own maintenance window if
   the table is large; verify the Flutter client still renders raw
   material quantities (the JSON-number-vs-string risk was checked and
   fixed in this session, but re-confirm on a real device).
5. Leave all three flags off for a week of production traffic, read the
   `*.would_reject` / `*.allocation.would_reject` logs, then flip them
   one at a time.
6. Do not touch step 05 beyond `variants:find-duplicates` (read-only)
   until step 04 has been live for several days with a flat duplicate
   count.

## Handoff notes for whoever continues this

- **Nothing here has touched a real database.** Migrations are believed
  correct by reading and by matching this codebase's existing raw-`ALTER`
  pattern (`2026_04_07_000006`, `2026_04_07_000007`), but have not been
  run. Run them on a staging copy of production before trusting them.
- **Phase-0 must ship first.** Confirm `erp.tgc-carpets.uz` is running
  phase-0's commits before starting phase-1's `DEPLOY.md`.
- **The core rule still carries forward:** one writer per fact, any cache
  of it gets a reconcile command. Step 01's `lineTotal()`, step 06's
  `deleted_at`, and step 05's `product_variant_merges` table are all
  direct applications of it. Phase-2's `production_events` table is the
  big one still ahead.
- **Step 05 is the one to pick up next**, but only after step 04 has
  earned its several quiet days in production. Read
  `instructions/phase-1/05-variant-unique-constraint.md` in full — it is
  the most consequential file in this phase, and the tooling built here
  is deliberately inert until a human drives it.
