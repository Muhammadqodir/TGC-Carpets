-- ============================================================================
-- Phase 0 pre-deploy reconciliation queries — READ ONLY.
--
-- Run every query in this file against a read replica or a fresh copy of
-- production BEFORE deploying the phase-0 code changes. They measure how
-- much damage the bugs being fixed have already done. Do not act on the
-- results automatically — each one needs a human decision (see the note
-- under each query). Fixing the code stops new damage; it does not repair
-- what is already there.
--
-- See instructions/README.md ("Measure before you fix") and
-- instructions/00-audit-report.md.
-- ============================================================================


-- ── 1. LOGIC-1 / phase-0/02 — phantom stock from reversed documents ─────────
-- Orphaned ledger rows (warehouse_document_item_id IS NULL because the
-- document/item was deleted) whose net is non-zero. A correctly reversed
-- document nets to zero; anything else is stock the reversal-direction bug
-- added or failed to remove.
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END) AS net
FROM stock_movements
WHERE warehouse_document_item_id IS NULL
GROUP BY product_variant_id
HAVING net <> 0;
-- Any row: that variant's live stock is off by `net` units. Cross-check
-- against a physical count before adjusting anything.


-- ── 2. LOGIC-1 / phase-0/03 — documents whose type disagrees with their ledger ─
-- A type-only PATCH (phase-0/03) or a reversal in the wrong direction
-- (phase-0/02) leaves the document's stated type and its own stock
-- movements telling different stories.
SELECT wd.id, wd.type AS document_type,
       SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE -sm.quantity END) AS ledger_net
FROM warehouse_documents wd
JOIN warehouse_document_items wdi ON wdi.warehouse_document_id = wd.id
JOIN stock_movements sm ON sm.warehouse_document_item_id = wdi.id
GROUP BY wd.id, wd.type
HAVING (wd.type = 'out' AND ledger_net > 0)
    OR (wd.type IN ('in','return','adjustment') AND ledger_net < 0);
-- Any row: this document is already corrupted. Report the list to the
-- owner rather than auto-correcting — each one needs a human decision
-- about which version (document or ledger) is true.


-- ── 3. PROD-2 / phase-0/05 — defect_quantity vs defect_document_items ───────
-- The two sources of truth for "how many units are defective" on a batch
-- item. They must always match; PROD-2 (deleting a defect document without
-- decrementing) is the reason they don't.
SELECT pbi.id,
       pbi.production_batch_id,
       pbi.defect_quantity,
       COALESCE(SUM(ddi.quantity), 0) AS from_documents
FROM production_batch_items pbi
LEFT JOIN defect_document_items ddi ON ddi.production_batch_item_id = pbi.id
GROUP BY pbi.id, pbi.production_batch_id, pbi.defect_quantity
HAVING pbi.defect_quantity <> from_documents;
-- Any row: defect_quantity is stale. Some of these batches will have
-- auto-completed early (see query 5) — carpets that were ordered were
-- never woven. Report to the owner; do not silently rewrite the counter.


-- ── 4. PROD-1 / phase-0/06 — orphaned pointers from batch-item deletion ─────
-- A batch edit (PROD-1) deletes and recreates production_batch_items,
-- orphaning any warehouse_document_items that pointed at the old (now
-- deleted) item ids. These pointers are polymorphic with no FK, so the
-- database allowed it silently.
SELECT wdi.id, wdi.source_id, wdi.warehouse_document_id
FROM warehouse_document_items wdi
LEFT JOIN production_batch_items pbi ON pbi.id = wdi.source_id
WHERE wdi.source_type = 'production_batch_item'
  AND wdi.source_id IS NOT NULL
  AND pbi.id IS NULL;
-- Any row: this bug has already fired. The corresponding carpets carry
-- physical QR labels that scan to nothing (their item id no longer
-- exists). Report the count to the owner.


-- ── 5. PROD-2 knock-on effect — batches that may have completed early ───────
-- Cross-reference with query 3: a batch item where defect_quantity is
-- inflated may have satisfied `produced_quantity < (planned_quantity -
-- defect_quantity)` early and auto-completed before every unit was woven.
SELECT pb.id AS batch_id, pb.batch_title, pb.status, pb.completed_datetime,
       pbi.id AS item_id, pbi.planned_quantity, pbi.produced_quantity, pbi.defect_quantity,
       (pbi.planned_quantity - pbi.produced_quantity - pbi.defect_quantity) AS unaccounted_units
FROM production_batch_items pbi
JOIN production_batches pb ON pb.id = pbi.production_batch_id
WHERE pb.status = 'completed'
  AND (pbi.produced_quantity + pbi.defect_quantity) < pbi.planned_quantity;
-- Any row: `unaccounted_units` carpets were ordered but the batch closed
-- before they were produced or recorded as defective. Worth an explicit
-- conversation with production about whether the shortfall is real.


-- ── 6. STRUCT-1 (context, not fixed in phase 0) — split-stock variants ──────
-- Not part of phase 0 (fix lands in phase-1/04–05), but worth running once
-- so the owner has the number: the same physical variant registered twice
-- because the warehouse path omits product_edge_id.
SELECT product_color_id, product_size_id, COUNT(*) AS variant_rows
FROM product_variants
WHERE product_edge_id IS NULL
GROUP BY product_color_id, product_size_id
HAVING COUNT(*) > 0;
-- This just counts NULL-edge variants; cross-reference by hand against
-- non-NULL-edge rows with the same color+size to find true duplicates.
