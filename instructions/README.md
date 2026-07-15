# TGC Carpets — backend upgrade instructions

Working documents for fixing the ERP backend, from the audit of **14 July 2026**.

- **[00-audit-report.md](00-audit-report.md)** — the full audit. Read this first. Every instruction file below refers back to a finding ID (`CALC-1`, `PROD-2`, `STRUCT-3`, `LOGIC-1`, `SCAN-1`…) defined there.
- **phase-0/** — stop the bleeding. 11 audited steps + 1 found live during testing (`12-guard-order-item-deletion.md`), ~3 days. Ship immediately. All 12 are implemented — see [phase-0/DEPLOY.md](phase-0/DEPLOY.md) for how to ship them without downtime or data loss, [phase-0/reconcile-before-deploy.sql](phase-0/reconcile-before-deploy.sql) for the read-only queries to run first, and [phase-0/COMPLETION-REPORT.md](phase-0/COMPLETION-REPORT.md) for full status and handoff context.
- **phase-1/** — make the money and stock trustworthy. 9 steps, ~2 weeks.
- **phase-2/** — the data structure upgrade. 8 steps, ~3 weeks. The main event.
- **phase-3/** — make it an advanced ERP. 8 steps, ongoing.

Each step is one file. Files are numbered in the order they should be done **within** a phase, and phases are done in order. Every file states its own severity, effort, whether it is safe to ship to the live system, and what it depends on.

**Phase 0 at a glance** — all eleven are pure bug fixes with no schema change, no API contract change, and no client release:

| Step | Fixes |
|---|---|
| [01](phase-0/01-fix-dashboard-endpoint.md) | Dashboard 500s on every call — two independent bugs, not one |
| [02](phase-0/02-fix-reversal-direction.md) | Deleting a warehouse document can *add* stock |
| [03](phase-0/03-reject-type-only-patch.md) | A type-only PATCH leaves document and ledger disagreeing |
| [04](phase-0/04-fix-warehouse-update-request.md) | Warehouse document editing fails 100% of the time |
| [05](phase-0/05-decrement-defect-quantity-on-delete.md) | Deleting a defect document leaves the counter inflated forever |
| [06](phase-0/06-guard-batch-item-deletion.md) | Editing a batch wipes its production history |
| [07](phase-0/07-fix-invoice-sqm-columns.md) | The client-facing invoice contradicts itself on m² |
| [08](phase-0/08-fix-empty-date-params.md) | A cleared date picker silently zeroes the whole report |
| [09](phase-0/09-cap-per-page.md) | One query parameter can take the server down |
| [10](phase-0/10-fix-topproducts-filter-breakdowns.md) | Filtered percentages reach 400% |
| [11](phase-0/11-fix-qr-scan-format.md) | No printed QR label can be scanned — ever |

## Ground rules

**The factory is running on this system.** Every change is judged on whether it can ship without downtime or a coordinated client release. Each instruction file states this explicitly under *Safe on live*.

**There are no tests and no CI.** Nothing will catch a regression for you. This is why every file has a *How to verify* section with manual steps, and why `phase-3/01-tests-and-ci.md` exists. Until that lands, verification is your own eyes on the database.

**Never change a column in place.** For any structural change, use expand → dual-write → backfill → verify → switch reads → contract. Each of those five is separately shippable, and you can stop after any of them.

**Measure before you fix.** Several bugs have already corrupted live data. Fixing the code stops new damage; it does not repair what is there. Run the reconciliation queries read-only against production *first*, so you know the size of the problem and can prove the fix worked.

## Order of operations that actually matters

These are not preferences. Getting them backwards causes harm:

| Do this first | Before this | Why |
|---|---|---|
| `phase-0/02` fix reversal direction | `phase-0/04` fix warehouse update request | Repairing the endpoint without fixing the reversal unmasks the corruption bug on a path that currently cannot reach it |
| `phase-1/01` single money formula | `phase-0/01` restoring `shipments_amount` | `shipment_items.total` no longer exists, so the dashboard's revenue figure must use the shared formula rather than become a fifth copy of it |
| `phase-1/04` pass `product_edge_id` | `phase-1/05` variant unique constraint | Otherwise you dedupe and the writers immediately create fresh duplicates |
| `phase-2/01` `production_events` table | `phase-2/04` repoint analytics | Analytics needs a real `occurred_at` to read from |
| `phase-2/03` backfill | `phase-2/04` repoint analytics | Otherwise historical periods read as zero |
| Reconciliation queries | Any data fix | Measure first, so you can prove the fix worked |
| Audit who calls what | `phase-1/09` apply role middleware | The middleware has never run — assume nothing about which roles need which endpoints |

## The one rule worth internalising

Almost every finding in the audit is the same shape: **the same fact is computed in two places that drift apart.** Stock is `SUM(movements)` *and* `warehouse_received_quantity`. A line total is derived four ways. "Incoming" has two definitions in one file. Defects live in `defect_document_items` *and* in `defect_quantity`.

So, when writing anything new here:

> **One writer per fact. Any cache of it gets a reconcile command that runs on a schedule.**

If a number cannot be recomputed from source, it is not trustworthy — it is just old.

## Status

Nothing here is implemented yet. This is a plan, not a changelog. If you complete a step, note it in that step's file rather than deleting the file — the reasoning is worth keeping.
