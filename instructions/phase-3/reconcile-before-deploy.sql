-- ============================================================================
-- Phase 3 pre-deploy reconciliation queries — READ ONLY.
--
-- Run every query in this file against a read replica or a fresh copy of
-- production BEFORE deploying the phase-3 code, and BEFORE running the
-- production:backfill-units command. They measure the size of what phase-3
-- is about to expose, and answer two decisions the instruction files
-- explicitly leave to a human (marked below). Do not act on the results
-- automatically.
--
-- See instructions/README.md ("Measure before you fix"),
-- instructions/phase-3/DEPLOY.md, and each numbered step file.
-- ============================================================================


-- ── 1. Step 03 Path A/B decision input ──────────────────────────────────────
-- Did anyone ever actually try to schedule a batch ahead of time? This
-- session could not run this query (no DB connectivity) and defaulted to
-- Path B (delete the unused 'planned' state) per the instruction file's own
-- "default to Path B if the answer is ambiguous" guidance. Run this before
-- trusting that default — if genuinely_scheduled_ahead is material, Path A
-- (build real scheduling) should have been taken instead, and this whole
-- step needs redoing before deploy.
SELECT
    COUNT(*) AS total,
    SUM(planned_datetime IS NULL) AS no_planned_date,
    SUM(ABS(TIMESTAMPDIFF(MINUTE, planned_datetime, created_at)) <= 5) AS planned_equals_created,
    SUM(planned_datetime > DATE_ADD(created_at, INTERVAL 1 HOUR)) AS genuinely_scheduled_ahead
FROM production_batches;


-- ── 2. Step 03 migration guard, run manually first ──────────────────────────
-- Must be 0. The migration itself refuses to proceed if this is non-zero
-- (see 2026_07_16_000001_drop_planned_status_from_production_batches.php),
-- but confirm it on the real database before trusting an automated guard on
-- a live system.
SELECT COUNT(*) AS batches_currently_planned
FROM production_batches
WHERE status = 'planned';


-- ── 3. Step 05 — how many adjustment documents exist today, and what did
--      they actually do? ────────────────────────────────────────────────────
-- Every one of these was mapped to TYPE_IN under the old unconditional rule.
-- The migration backfills direction='in' for all of them, which is exactly
-- what happened — this query is just visibility into how many, and how
-- large, before the fix ships.
SELECT
    COUNT(*) AS adjustment_documents,
    COALESCE(SUM(wdi.quantity), 0) AS total_quantity_adjusted_in
FROM warehouse_documents wd
JOIN warehouse_document_items wdi ON wdi.warehouse_document_id = wd.id
WHERE wd.type = 'adjustment';


-- ── 4. Step 04 currency sanity check — is anything already NOT actually USD? ─
-- If a max price is in the millions, someone has already typed UZS into a
-- field the invoice labels "$", and there is a data-correction job to do
-- BEFORE this ships a currency column defaulting everything to 'USD' — that
-- default is only correct if this assumption holds.
SELECT MIN(price) AS min_price, MAX(price) AS max_price, AVG(price) AS avg_price
FROM shipment_items;

SELECT MIN(amount) AS min_amount, MAX(amount) AS max_amount, AVG(amount) AS avg_amount
FROM payments;


-- ── 5. Step 07 — how many variants already have negative available stock,
--      i.e. how much double-promising has already happened? ────────────────
-- This is the backfill's first deliverable per the instruction file: take
-- this list to the factory before trusting the reservation numbers. Expect
-- some negative rows — that is real, pre-existing over-promising surfacing
-- for the first time, not a bug in the query.
SELECT
    oi.product_variant_id,
    SUM(oi.quantity - COALESCE(shipped.qty, 0)) AS unshipped_reserved_would_be,
    (
        SELECT COALESCE(SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
        FROM stock_movements sm
        WHERE sm.product_variant_id = oi.product_variant_id
    ) AS physical_stock,
    (
        SELECT COALESCE(SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE -sm.quantity END), 0)
        FROM stock_movements sm
        WHERE sm.product_variant_id = oi.product_variant_id
    ) - SUM(oi.quantity - COALESCE(shipped.qty, 0)) AS would_be_available
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
LEFT JOIN (
    SELECT order_item_id, SUM(quantity) AS qty
    FROM shipment_items
    GROUP BY order_item_id
) shipped ON shipped.order_item_id = oi.id
WHERE o.status NOT IN ('canceled', 'shipped')
  AND oi.quantity - COALESCE(shipped.qty, 0) > 0
GROUP BY oi.product_variant_id
HAVING would_be_available < 0
ORDER BY would_be_available ASC;


-- ── 6. Step 02 — how big is the production_units backfill? ──────────────────
-- Row count for production:backfill-units. One row written per unit of
-- produced_quantity. Time this against a staging copy before running on
-- live; do not discover the duration during a maintenance window.
SELECT
    COUNT(*) AS items_with_production,
    SUM(produced_quantity) AS units_to_backfill
FROM production_batch_items
WHERE produced_quantity > 0;


-- ── 7. Step 02 — reprint gap preview ─────────────────────────────────────────
-- Not runnable before deploy (production_units does not exist yet) — this is
-- the query to run AFTER Stage 2's backfill, included here so it's in one
-- place with the rest of this file's queries. Expect drift to be negative
-- (unit_count < produced_quantity) wherever a reprint happened historically;
-- that gap is the whole point of the file. See
-- instructions/phase-3/02-production-units-serials.md and
-- app/Console/Commands/ProductionUnitsReconcile.php (production:reconcile-units
-- does this same comparison on a schedule once Stage 2 has run).
-- SELECT i.id, i.production_batch_id, i.produced_quantity, COUNT(u.id) AS unit_count,
--        i.produced_quantity - COUNT(u.id) AS drift
-- FROM production_batch_items i
-- LEFT JOIN production_units u
--   ON u.production_batch_item_id = i.id AND u.status IN ('good','received','shipped')
-- WHERE i.produced_quantity > 0
-- GROUP BY i.id, i.production_batch_id, i.produced_quantity
-- HAVING drift <> 0
-- ORDER BY ABS(drift) DESC;
