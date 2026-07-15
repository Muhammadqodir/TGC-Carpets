# Phase 0 — completion report

**Written:** 2026-07-15, at the end of the phase-0 work session, for handoff into a new session starting phase-1.

## Status: code complete, dev-tested in part, NOT yet on production

All 12 phase-0 fixes (11 from the 14 July audit + 1 found live during dev testing) are implemented, committed, and pushed:

```
6f23aa7  Implement phase-0: stop the bleeding (11 critical/high bug fixes)
d77ba8f  git pull   ← contains 12-guard-order-item-deletion.md's code fix + the app_constants.dart dev/prod URL fix
```

Both are on `dev` locally **and** on `origin/dev` (verified via `git fetch` — confirmed present on GitHub, not just local).

**Production (`erp.tgc-carpets.uz`) is still running the pre-phase-0 code.** Nothing has been deployed there yet. `dev.tgc-carpets.uz` is running these fixes, against a copy of the database taken before this session (frozen at copy time, now diverging as it's used for testing).

## What shipped

| # | Fix | Finding | Verified on dev? |
|---|---|---|---|
| 01 | Dashboard 500s (missing import + dropped column) | CALC-2 | Not explicitly confirmed |
| 02 | Reversal direction derived from ledger, not mutable column | LOGIC-1 | Not explicitly confirmed |
| 03 | Reject type-only PATCH on warehouse document | LOGIC-1 | Not explicitly confirmed |
| 04 | Missing `product_color_id` validation rule on update | LOGIC-2 | Not explicitly confirmed |
| 05 | Decrement `defect_quantity` on defect document delete | PROD-2 | Not explicitly confirmed |
| 06 | Guard batch item deletion when production exists | PROD-1 | Not explicitly confirmed |
| 07 | Invoice m² columns (per-unit vs total) | CALC-4 | Not explicitly confirmed |
| 08 | Empty date params no longer zero analytics | CALC-5 | Not explicitly confirmed |
| 09 | `per_page` capped at 200 everywhere | LOGIC-6 | N/A (no visible UI effect) |
| 10 | Top-products filter breakdown percentages | CALC-5 | Not explicitly confirmed |
| 11 | QR scan format widened; reprint-from-history fixed | SCAN-1 | Not explicitly confirmed |
| 12 | Guard order item deletion when production exists | *(not in original audit — found live)* | **Confirmed reproduced pre-fix**, fix not yet re-tested |

**Important gap:** only #12 was actually exercised through the running app this session (that's how it was found — a user clicked "edit order" and watched production progress disappear). Items 01–11 have **not** been individually clicked through in the app yet. Reconciliation SQL was run against the dev database copy and came back clean for the data-integrity findings (queries 1–5), which is reassuring but is not the same as functional UI testing, and is not production data anyway (see caveat below).

**Before promoting to production, run the full checklist in [DEPLOY.md](DEPLOY.md) Step 3** (dashboard loads, warehouse doc PATCH rejects type-only changes, create/delete nets to zero stock, QR scan resolves a real physical label, order edit with linked production rejects) against dev, item by item, not just the SQL reconciliation.

## Item 12 — why it's not in the original audit

Discovered by manually testing the app against dev after fixing items 1–11. Same bug shape as PROD-1 (`phase-0/06`), just on `Order` instead of `ProductionBatch`: `OrderService::update()` deletes and recreates all `order_items` on any item-list edit; `production_batch_items.source_order_item_id` is `nullOnDelete`, so the delete doesn't error, it silently orphans the link between an order and its in-progress production. Full writeup: [12-guard-order-item-deletion.md](12-guard-order-item-deletion.md).

**This means the original audit's "same fact computed in two places that drift" pattern has now shown up three times** (`ProductionBatchService::update()`, `WarehouseDocumentService::update()`, `OrderService::update()` — all three used to do "delete all child rows, recreate fresh" as their edit strategy). Worth explicitly checking during phase-1/phase-2 whether any other `*Service::update()` does the same delete-and-recreate pattern for a relation that something else keys off of. Checked already: `ShipmentService` has no `update()` method at all (shipments can only be created/deleted), so that one's not exposed to this bug class.

## Reconciliation queries — what's been run, what hasn't

`reconcile-before-deploy.sql` now has 7 queries (was 6; added #6 for the item-12 finding). **All 7 have only been run against the dev database copy so far — none have been run against real production.** The dev run came back clean for queries 1–5 (no drift found in that snapshot) and query 6 wasn't re-run after being added.

**Before deploying to production**, run the full file against production's real database (read-only, safe — see the file's own header and `DEPLOY.md` Step 1) to get the actual numbers. A clean result on the dev copy tells you nothing about production; it's a different, older, now-diverging dataset.

## Known rough edges from this session (context, not action items)

- **Server-side git setup was messy during dev deployment.** The dev server's `tgc_backend` folder briefly had a duplicate/stray `.git` from an accidental `git init` inside the wrong directory (since removed), and a `dubious ownership` git safety check needed a `safe.directory` exception added. Both resolved. If redeploying to a *new* server in future, clone fresh into a new directory rather than retrofitting git onto a manually-copied folder — much less error-prone.
- **The Flutter client has no build-flavor/environment system.** `tgc_client/lib/core/constants/app_constants.dart` hardcodes `baseUrl`/`storageUrl`/`publicApiUrl` as `static const`. Pointing a build at dev requires hand-editing this file and reverting it before any real production build — already reverted and confirmed clean (matches committed production URLs, verified via `git diff HEAD`). If dev testing becomes routine, worth building this as a proper `--dart-define`-based flavor instead of hand-editing — flagged to the user during the session, not yet actioned.
- **`public/info.php`** was found sitting untracked in the dev server's docroot (looks like a leftover `phpinfo()` page) — a minor info-disclosure risk, unrelated to phase-0, flagged but not removed (wasn't asked to).

## Handoff notes for phase-1

- Read `instructions/README.md`'s "Order of operations that actually matters" table before starting — several phase-1 steps have hard dependencies on what phase-0 changed (e.g. `phase-1/01`'s money formula must be the thing that reinstates `shipments_amount`, which phase-0/01 removed rather than duplicating).
- The core rule carries forward: **one writer per fact, any cache of it gets a reconcile command.** Phase-1's money formula (CALC-3) and phase-2's `production_events` table are both direct applications of this. Item 12 above is a live example of the failure mode this rule prevents — worth using as the motivating case when explaining phase-2 to the owner.
- The database has **not** had any of this session's phase-0 fixes validated against it yet. Don't assume phase-0's data-integrity guarantees hold on production until DEPLOY.md has actually been run there and the post-deploy reconciliation (DEPLOY.md Step 5) confirms the numbers stopped growing.
