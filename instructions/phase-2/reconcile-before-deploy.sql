-- ============================================================================
-- Phase 2 pre-deploy reconciliation queries — READ ONLY.
--
-- Run every query in this file against a read replica or a fresh copy of
-- production BEFORE deploying the phase-2 code, and BEFORE running either
-- backfill command or flipping ANALYTICS_SOURCE. They measure the size of
-- what phase-2 is about to expose (it does not create these problems — the
-- audit found them in July; this phase makes them visible and reconcilable
-- instead of silently absorbed). Do not act on the results automatically;
-- several need a human decision (marked below).
--
-- See instructions/README.md ("Measure before you fix"),
-- instructions/phase-2/DEPLOY.md, and each numbered step file.
-- ============================================================================


-- ── 1. Sizing — how big is the backfill (step 03)? ──────────────────────────
-- Row count for BackfillProductionEvents. Each row writes up to 2 events
-- (produced + defect). Time this against a staging copy before running on
-- live; do not discover the duration during a maintenance window.
SELECT COUNT(*) AS items_to_backfill
FROM production_batch_items
WHERE produced_quantity > 0 OR defect_quantity > 0;


-- ── 2. Backfill proxy distribution — how much history has a completed_datetime,
--      vs. falling back to started_datetime or created_at (step 03)? ────────
-- The backfill's occurred_at proxy is completed_datetime > started_datetime >
-- created_at, in that priority order. A large "no timestamp at all" number
-- means many items will fall back to created_at, which is the least
-- accurate proxy the instruction file describes. Understand this before
-- showing the owner step 04's history.
SELECT
    SUM(pb.completed_datetime IS NOT NULL) AS has_completed_datetime,
    SUM(pb.completed_datetime IS NULL AND pb.started_datetime IS NOT NULL) AS falls_back_to_started,
    SUM(pb.completed_datetime IS NULL AND pb.started_datetime IS NULL) AS falls_back_to_created_at
FROM production_batch_items pbi
JOIN production_batches pb ON pb.id = pbi.production_batch_id
WHERE pbi.produced_quantity > 0 OR pbi.defect_quantity > 0;


-- ── 3. PROD-4 — how many items are ALREADY blocked from recording a real
--      defect, right now, by the bug step 05 fixes? ─────────────────────────
-- Every row here is a fully-labelled (or over-labelled-relative-to-plan)
-- batch item where StoreDefectDocumentRequest's old formula computes
-- `remaining = 0` — meaning nobody can currently file a defect against it,
-- even though the carpets are real and QC may be finding faults on them
-- today. This is the count of "silently blocked" work the fix unblocks.
SELECT COUNT(*) AS items_currently_blocked_from_any_defect
FROM production_batch_items
WHERE (planned_quantity - produced_quantity) <= 0
  AND produced_quantity > 0;


-- ── 4. PROD-2 — phantom defect_quantity from already-deleted defect
--      documents (step 05 §5's sizing query, reproduced here for convenience) ─
-- phase-0/05 stopped new leaks (destroy() now decrements), but anything
-- deleted BEFORE phase-0/05 shipped is still phantom-inflated and
-- unrecoverable — see instructions/phase-2/05's "Repair the damage already
-- done". Take this list to the owner; only he can say which look real.
SELECT i.id, i.planned_quantity, i.produced_quantity, i.defect_quantity,
       COALESCE(SUM(di.quantity), 0) AS documented_defects,
       i.defect_quantity - COALESCE(SUM(di.quantity), 0) AS phantom
FROM production_batch_items i
LEFT JOIN defect_document_items di ON di.production_batch_item_id = i.id
WHERE i.defect_quantity > 0
GROUP BY i.id, i.planned_quantity, i.produced_quantity, i.defect_quantity
HAVING phantom <> 0
ORDER BY phantom DESC;


-- ── 5. Step 07 — stock already negative, before the lockable balance exists ──
-- Any row is a carpet shipped that never existed (the race
-- product_variant_stock's SELECT ... FOR UPDATE closes). The balance row
-- will make these visible where the current HAVING quantity_warehouse > 0
-- filter hides them. Take the list to whoever owns the physical count —
-- this is not something --fix on stock:reconcile should ever paper over.
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END) AS qty
FROM stock_movements
GROUP BY product_variant_id
HAVING qty < 0
ORDER BY qty;


-- ── 6. Sizing — how big is stock:backfill-balances (step 07)? ───────────────
SELECT COUNT(*) AS movement_rows, COUNT(DISTINCT product_variant_id) AS variants
FROM stock_movements;


-- ── 7. Step 04 — proof the report currently moves history around ────────────
-- Batch items whose produced_quantity was set by production but whose
-- updated_at has since been pushed forward by a warehouse receipt or a
-- defect entry — i.e. the legacy report is currently attributing this
-- item's output to a later month than when it was actually woven. Large
-- counts here are the concrete evidence to show the owner before flipping
-- ANALYTICS_SOURCE — see instructions/phase-2/04's "Rollout".
SELECT pbi.id, pbi.produced_quantity, pb.completed_datetime, pbi.updated_at,
       DATEDIFF(pbi.updated_at, pb.completed_datetime) AS days_report_moved_output_forward
FROM production_batch_items pbi
JOIN production_batches pb ON pb.id = pbi.production_batch_id
WHERE pbi.produced_quantity > 0
  AND pb.completed_datetime IS NOT NULL
  AND DATE(pbi.updated_at) <> DATE(pb.completed_datetime)
ORDER BY days_report_moved_output_forward DESC
LIMIT 50;
