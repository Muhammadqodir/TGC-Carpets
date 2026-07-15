-- ============================================================================
-- Phase 1 pre-deploy reconciliation queries — READ ONLY.
--
-- Run every query in this file against a read replica or a fresh copy of
-- production BEFORE deploying the phase-1 code, and BEFORE flipping any of
-- the phase-1 feature flags from log-only to enforcing. They measure how
-- much the numbers move and how many requests the new validation would
-- reject. Do not act on the results automatically — several need a human
-- decision (marked below). Fixing the code stops new drift; it does not
-- repair what is already there.
--
-- See instructions/README.md ("Measure before you fix"),
-- instructions/phase-1/DEPLOY.md, and each numbered step file.
-- ============================================================================


-- ── 1. Step 01 — shipments whose per-line and per-shipment rounding disagree ─
-- Every row here is a shipment whose invoice, ledger, and debit-list figures
-- currently disagree by a cent or more. `per_line` is what all three will
-- read after step 01 ships.
SELECT s.id,
       SUM(ROUND(CASE WHEN p.unit = 'm2' AND ps.id IS NOT NULL
                      THEN si.price * ps.length * ps.width * si.quantity / 10000
                      ELSE si.quantity * si.price END, 2))          AS per_line,
       ROUND(SUM(CASE WHEN p.unit = 'm2' AND ps.id IS NOT NULL
                      THEN si.price * ps.length * ps.width * si.quantity / 10000
                      ELSE si.quantity * si.price END), 2)          AS per_shipment
FROM shipment_items si
JOIN shipments s         ON s.id  = si.shipment_id
JOIN product_variants pv ON pv.id = si.product_variant_id
JOIN product_colors pc   ON pc.id = pv.product_color_id
JOIN products p          ON p.id  = pc.product_id
LEFT JOIN product_sizes ps ON ps.id = pv.product_size_id
GROUP BY s.id
HAVING per_line <> per_shipment
ORDER BY ABS(per_line - per_shipment) DESC;
-- Tell the office: ledger and debit-list totals for these shipments will
-- move by a cent or two after step 01 ships, to match the invoice PDF.


-- ── 2. Step 02/03 — orders already over-shipped, before enforcement exists ──
-- Rows here already have more shipped than ordered. Step 02's validator
-- would reject any *new* over-ship attempt once enforcing, but these are
-- historical — they will keep showing up in every future audit until
-- someone decides what to do with the physical/financial overage.
SELECT oi.id AS order_item_id, oi.order_id, o.client_id, oi.quantity AS ordered,
       COALESCE(SUM(si.quantity), 0) AS shipped,
       COALESCE(SUM(si.quantity), 0) - oi.quantity AS overage
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
LEFT JOIN shipment_items si ON si.order_item_id = oi.id
GROUP BY oi.id, oi.order_id, o.client_id, oi.quantity
HAVING overage > 0
ORDER BY overage DESC;
-- Non-empty: over-shipping already happens in production. Read
-- shipment.validation.would_reject logs for a full week (see phase-1/02)
-- before flipping SHIPMENTS_ENFORCE_ITEM_VALIDATION — some of these may be
-- a legitimate business practice (e.g. replacing a defect) the validator
-- does not yet know about.


-- ── 3. Step 03 — stock already negative, before the transaction fix ─────────
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in'  THEN quantity ELSE 0 END)
     - SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END) AS stock
FROM stock_movements
GROUP BY product_variant_id
HAVING stock < 0;
-- Any row is a variant that has already over-shipped. Step 03 cannot repair
-- it, only stop the next one. Hand the list to whoever owns the physical
-- count.


-- ── 4. Step 04/05 — split-stock variants from the missing product_edge_id ───
-- The (colour, size) view — catches NULL-vs-real-edge splits regardless of
-- which edge the non-NULL side has.
SELECT product_color_id, product_size_id,
       COUNT(*)                                              AS variant_count,
       GROUP_CONCAT(id ORDER BY id)                          AS variant_ids,
       GROUP_CONCAT(COALESCE(product_edge_id, 'NULL') ORDER BY id) AS edges,
       GROUP_CONCAT(sku_code ORDER BY id SEPARATOR ' | ')    AS skus
FROM product_variants
GROUP BY product_color_id, product_size_id
HAVING COUNT(*) > 1
ORDER BY variant_count DESC;
-- Every group containing a NULL edge alongside a real one is a split caused
-- by the step-04 bug. This is step 05's input — do not act on it directly;
-- run `php artisan variants:find-duplicates` instead (same query plus the
-- strict color+size+edge view and a stock-bearing NULL-edge check), and see
-- instructions/phase-1/05-variant-unique-constraint.md before merging
-- anything.


-- ── 5. Step 07 — production/warehouse allocation already out of sync ────────
-- Batch items where the warehouse received more than production produced —
-- evidence of the vanishing-remainder bug already firing.
SELECT pbi.id, pbi.product_variant_id, pbi.produced_quantity, pbi.warehouse_received_quantity,
       pbi.warehouse_received_quantity - pbi.produced_quantity AS excess
FROM production_batch_items pbi
WHERE pbi.warehouse_received_quantity > pbi.produced_quantity
ORDER BY excess DESC;
-- Non-empty and large: this is normal operating procedure, not a rare
-- fault. Do NOT set WAREHOUSE_ENFORCE_ALLOCATION_CHECK=true yet — leave it
-- log-only and read warehouse.allocation.would_reject for a week first
-- (see phase-1/07-symmetric-fifo-allocation.md "Rollback").


-- ── 6. Step 08 — raw materials already spent past their received balance ────
SELECT rm.id, rm.name, rm.unit,
       COALESCE(SUM(CASE WHEN m.type = 'received' THEN m.quantity ELSE 0 END), 0)
     - COALESCE(SUM(CASE WHEN m.type = 'spent'    THEN m.quantity ELSE 0 END), 0) AS balance
FROM raw_materials rm
LEFT JOIN raw_material_stock_movements m ON m.material_id = rm.id
GROUP BY rm.id, rm.name, rm.unit
HAVING balance < 0
ORDER BY balance;
-- Empty: safe to set RAW_MATERIALS_ENFORCE_STOCK_VALIDATION=true directly.
-- Non-empty: log-only for a week first, per phase-1/08.


-- ── 7. Step 08 — raw material quantities the DOUBLE→DECIMAL(12,3) ALTER
--      would actually change ───────────────────────────────────────────────
SELECT id, material_id, quantity
FROM raw_material_stock_movements
WHERE quantity <> ROUND(quantity, 3);
-- Non-empty is almost certainly float noise being corrected (e.g. 12.5
-- stored as 12.499999999999998), which is the point of the migration. Look
-- at the rows rather than assuming — see phase-1/08's "How to verify" step
-- 5. Also check row count separately before running the ALTER: it rewrites
-- every row and locks the table.
SELECT COUNT(*) AS row_count FROM raw_material_stock_movements;


-- ── 8. Step 06 — soft-deleted clients who still owe money ───────────────────
SELECT c.id, c.shop_name, c.deleted_at
FROM clients c
WHERE c.deleted_at IS NOT NULL
  AND EXISTS (SELECT 1 FROM shipments s WHERE s.client_id = c.id);
-- Non-empty: tell the office before deploying. These clients are about to
-- reappear in GET /api/v1/clients/debits (step 06's withTrashed()) showing
-- an outstanding balance. That is correct — the receivable was always
-- real — but it will look like a bug if nobody was warned.
