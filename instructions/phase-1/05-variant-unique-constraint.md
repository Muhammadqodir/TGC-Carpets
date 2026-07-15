# 05 — Merge duplicate variants and add the real unique constraint

Nothing at the database level enforces that `(product_color_id, product_size_id, product_edge_id)` is unique. This step reconciles the two disagreeing SKU generators, merges the duplicates that already exist, and adds the constraint that should have been there from the start.

**Severity: High / Effort: 3d / Safe on live: NO. This is the only step in phase 1 that mutates existing rows. Read the whole file before writing any code.**

## Why this matters

### The index that isn't

`database/migrations/2026_04_07_000006_reparent_product_variants_to_product_colors.php:57`:

```php
$table->index(['product_color_id', 'product_size_id'], 'variants_color_size_idx');
```

A plain index. Not unique. And `product_edge_id` is not in it — it did not exist until `2026_06_07_000002`, which added the column and never touched the index.

The only unique keys on `product_variants` are:

- `barcode_value` — `2026_04_07_000003_create_product_variants_table.php:34`
- `sku_code` — `2026_04_07_000007_move_sku_to_product_variants.php:51`

Neither expresses the business rule. The original author knew, and wrote it down in the create migration (lines 15-17):

> NOTE: MySQL does not enforce uniqueness on composite NULL columns, so
> the application service uses a transaction + SELECT FOR UPDATE to
> prevent duplicate (product_id, NULL) rows at the code level.

The service-layer guard is `ProductVariantService::findOrCreate` — a fast-path `SELECT` (lines 31-42) followed by an `INSERT` with a `catch (UniqueConstraintViolationException)` fallback (lines 78-100). The `SELECT` is racy by construction. The `catch` only fires on `sku_code` or `barcode_value`, because those are the only unique keys. **So the true guard against duplicate `(colour, size, edge)` is the `sku_code` index — an index on a derived string, not on the identity it stands for.** Whenever the SKU disagrees with the identity, the guard fails silently.

Which brings us to the reason it disagrees.

### The two SKU generators disagree on axis order

**Verified. Both quoted exactly.**

`database/migrations/2026_04_07_000007_move_sku_to_product_variants.php:44` (the backfill):

```sql
CASE WHEN ps.id IS NOT NULL THEN CONCAT('-', ps.length, 'x', ps.width) ELSE '' END
```

`app/Models/ProductVariant.php:57` (`generateSku`, used for every variant created since):

```php
$sku .= '-' . $size->width . 'x' . $size->length;
```

**`length × width` in the migration. `width × length` in the model.** For a 200×300 carpet the backfill wrote `...-200x300` and the model writes `...-300x200`. They are different strings, so they do not collide, so the `sku_code` unique index — the only thing actually guarding variant identity — **does not fire**. Two rows for the same physical carpet coexist happily.

There is a second, independent divergence in the same pair. `generateSku` appends an edge suffix (lines 60-62):

```php
if ($edgeCode) {
    $sku .= '-E' . strtoupper($edgeCode);
}
```

The backfill never emitted `-E` at all — the edge column did not exist in April. So every variant created before `2026_06_07_000002` has an edge-less SKU, was then backfilled to edge `R`, and now has a SKU that `generateSku` would never produce for it. `findOrCreate`'s own comment (lines 79-83) documents this as a known hazard it works around rather than fixes:

> Another request beat us to the INSERT (race condition), or the same
> SKU belongs to a variant with a different edge_id (old variants that
> were backfilled with an edge_id but whose sku_code predates the edge
> suffix format).

So there are three SKU generations in the table simultaneously: `length x width` with no edge (April backfill), `width x length` with no edge (model, pre-June), and `width x length` with `-E` (model, post-June). All three can describe the same carpet.

### What this costs

Duplicate variants split stock. Variant 77 holds the order and its shipments; variant 91 holds the warehouse receipts. `StockController` lists both. `ShipmentImportController`'s `STOCK_SUB` (lines 30-33) finds goods under one while the order points at the other. Stock reports are wrong in both directions at once: phantom stock on one ID, missing stock on the other.

Step 04 fixed the *producer* of new duplicates. This step repairs the *data* and installs the guard that stops it recurring.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | What |
|---|---|---|
| `app/Models/ProductVariant.php` | 37-65 | `generateSku` — reconcile axis order. |
| `database/migrations/` | new | Merge migration + constraint migration (separate files). |
| `app/Services/ProductVariantService.php` | 28-103 | Simplify once the real constraint exists. |
| `app/Console/Commands/` | new | The merge command, with dry-run. |

The five tables holding a `product_variant_id` FK, **all `restrictOnDelete`** — verified from the migrations:

| Table | Migration |
|---|---|
| `order_items` | `2026_04_09_000002:14` |
| `shipment_items` | `2026_04_13_000005:22` |
| `production_batch_items` | `2026_04_11_000003:16` |
| `warehouse_document_items` | `2026_04_07_000004:30` |
| `stock_movements` | `2026_04_07_000004:38` |

**The audit's list named only four — it omitted `warehouse_document_items`.** Miss it and the `DELETE` of the losing variant fails on the FK, mid-merge. Confirm the list yourself before you start:

```sql
SELECT TABLE_NAME, COLUMN_NAME, CONSTRAINT_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME = 'product_variants'
  AND TABLE_SCHEMA = DATABASE();
```

Use that output, not this table. If it returns a sixth table, the codebase has moved since this was written.

## The change

Five stages, each independently verifiable, each with its own deploy. **Do not compress them.**

### Stage 1 — Reconcile the SKU axis order

Decide which order is correct and make both agree. **Recommendation: keep the model's `width x length`** and rewrite the historical SKUs to match. Reasons: it is what every variant created in the last three months already uses; `ProductVariant::label()` (line 119) also renders `width}x{length`, as does `ShipmentService::generateAndStoreXlsx` (line 335) and the shipment-import ordering (lines 161-162). The `length x width` form exists only in one migration's backfill. The rest of the system says width-first.

Verify that claim before acting on it — it is the one place where a wrong call is expensive:

```bash
grep -rn 'width.*x.*length\|length.*x.*width' app/ resources/views/ database/migrations/
```

And ask the office which way round they read a size label. If staff read "200x300" as length-first, the *display* convention and the *SKU* convention differ, and you need to know that before you rewrite 3,000 SKUs.

Whichever you choose, the fix is a data migration that regenerates every SKU from a single source of truth:

```php
// Regenerate all sku_code values from ProductVariant::generateSku so that
// the April backfill, the pre-edge model output, and the current model
// output all converge on one format.
$variants = ProductVariant::with(['productColor.product', 'productColor.color', 'productSize', 'productEdge'])
    ->orderBy('id')
    ->cursor();

foreach ($variants as $variant) {
    $sku = ProductVariant::generateSku(
        $variant->productColor->product->name,
        $variant->productColor->product->product_quality_id,
        $variant->productColor->product->product_type_id,
        $variant->productColor->color->name,
        $variant->productSize,
        $variant->productEdge?->code,
    );
    // ... collision handling, see below
}
```

**This will collide, and the collisions are the point.** Two rows for the same carpet that were only distinct because their SKUs differed will now generate the *same* SKU. The `sku_code` unique index will reject the second. **Those collisions are your duplicate list.** Do not suppress them — collect them.

Run this in dry-run first and write the collisions to a report. They are the input to stage 3. If stage 1 produces zero collisions, either you have no duplicates (verify against the stage-2 query before believing it) or the regeneration is not doing what you think.

Practical ordering problem: you cannot `UPDATE` SKUs in place while the unique index is live and expect a clean run — an intermediate state may collide with a row not yet rewritten. Options, in order of preference:

1. Compute all new SKUs in PHP first, into a scratch table. Detect collisions there, resolve them (stage 3), and only then write. **Prefer this.**
2. Drop the `sku_code` unique index, rewrite, dedupe, re-add. Faster but leaves a window with no guard at all — and the `sku_code` index is currently the *only* guard. If a write lands in that window you have a new duplicate and no error. Only acceptable during a maintenance window with writes stopped.

### Stage 2 — Find the duplicates

The identity groups, ignoring SKU entirely:

```sql
SELECT product_color_id, product_size_id, product_edge_id,
       COUNT(*)                                   AS n,
       GROUP_CONCAT(id ORDER BY id)               AS variant_ids,
       GROUP_CONCAT(sku_code ORDER BY id SEPARATOR ' | ') AS skus
FROM product_variants
GROUP BY product_color_id, product_size_id, product_edge_id
HAVING COUNT(*) > 1
ORDER BY n DESC;
```

Note this groups `product_edge_id` with `NULL` as its own value — MySQL's `GROUP BY` treats NULLs as equal, unlike its unique indexes. So this query **does** find the NULL-edge splits from step 04, but as separate groups from their `R` counterparts. You need both views. Run step 04's query too:

```sql
-- The (colour, size) view — catches NULL-vs-R splits that the query above separates
SELECT product_color_id, product_size_id,
       COUNT(*)                                                    AS n,
       GROUP_CONCAT(id ORDER BY id)                                AS variant_ids,
       GROUP_CONCAT(COALESCE(product_edge_id, 'NULL') ORDER BY id) AS edges
FROM product_variants
GROUP BY product_color_id, product_size_id
HAVING COUNT(*) > 1;
```

**Judgement call, and it is not automatable:** a `(colour, size)` group with edges `{NULL, R}` is *probably* one carpet split by the step-04 bug, and should merge. A group with edges `{R, S}` is *two genuinely different products* and must not. A group with `{NULL, R, S}` needs a human to decide which product the NULL rows belong to — and the answer may be "some of each".

Do not guess. Produce the list, take it to whoever knows the products, and get a decision per group in writing. The merge command consumes that decision; it does not make it.

### Stage 3 — Merge, with dry-run and a reversible mapping table

Write an artisan command. **Dry-run is the default; `--force` is what actually writes.**

```php
// app/Console/Commands/MergeDuplicateVariants.php
protected $signature = 'variants:merge-duplicates
                        {--force : Actually write. Without this, reports only.}
                        {--group= : Merge only this colour-size-edge group.}';
```

Create the mapping table **first**, in its own migration, and keep it forever:

```php
Schema::create('product_variant_merges', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('loser_variant_id');     // deleted
    $table->unsignedBigInteger('survivor_variant_id');  // kept
    $table->json('loser_snapshot');                     // full row before deletion
    $table->json('repointed_counts');                   // {stock_movements: 12, order_items: 3, ...}
    $table->string('reason');                           // who decided, and why
    $table->timestamps();

    $table->index('loser_variant_id');
    $table->index('survivor_variant_id');
});
```

This table is what makes the merge reversible. Without it, a merge is a one-way door and the only rollback is a full database restore. **Do not skip it, and do not drop it after the merge succeeds** — a mis-merge may not be noticed for weeks, and this is the only record of what variant 91 used to be.

Per group, inside one transaction:

```php
DB::transaction(function () use ($survivorId, $loserIds) {
    foreach ($loserIds as $loserId) {
        $snapshot = DB::table('product_variants')->where('id', $loserId)->first();

        // Balance before, for the invariant check
        $before = $this->stockFor([$survivorId, $loserId]);

        $counts = [];
        // Every FK table from information_schema — verify the list, do not trust this one
        foreach (['stock_movements', 'order_items', 'shipment_items',
                  'production_batch_items', 'warehouse_document_items'] as $table) {
            $counts[$table] = DB::table($table)
                ->where('product_variant_id', $loserId)
                ->update(['product_variant_id' => $survivorId]);
        }

        // The invariant: summed stock across the pair must not move.
        $after = $this->stockFor([$survivorId]);
        if ($before !== $after) {
            throw new \RuntimeException(
                "Merge {$loserId} -> {$survivorId} changed stock: {$before} -> {$after}"
            );
        }

        DB::table('product_variant_merges')->insert([...]);

        // restrictOnDelete: this THROWS if any FK was missed. That is the guard.
        DB::table('product_variants')->where('id', $loserId)->delete();
    }
});
```

Three deliberate points:

- **The stock invariant is the real check.** Repointing rows must never change the summed balance across the pair — it is the same physical carpet, just re-labelled. If the sum moves, a table was missed or double-counted. Throw and roll back; do not log and continue.
- **`restrictOnDelete` is working for you.** All five FKs restrict, so if you missed a table the `DELETE` fails and the transaction rolls back. That is a feature. Do not "fix" it by loosening the FK.
- **`barcode_value` is unique and the loser holds one.** Deleting the row frees it. If barcodes are printed on physical labels, a loser's barcode is on a carpet on a shelf and deleting it means a scan returns nothing. **Check this before deleting anything.** `ProductVariantController::findByBarcode` (`routes/api.php:144`) is a live endpoint; the label printer at `/Users/mqodir/Documents/GitHub/TGC-Carpets/usb_label_print` may have printed it. If loser barcodes are in the wild, do not delete — repoint the barcode onto the survivor, or keep the loser row as a tombstone. This may change the whole shape of the merge; find out early.

Choose the survivor deterministically: **lowest ID** is usually right (oldest, most referenced), but check which row the *orders* point at — the one carrying order history is the one whose deletion hurts most. Record the choice in `reason`.

### Stage 4 — `product_edge_id` NOT NULL with a sentinel

**This is why the constraint cannot go on first.** MySQL permits unlimited NULLs in a unique index. `unique(color, size, edge)` with `edge = NULL` constrains **nothing** — you could insert a thousand `(12, 4, NULL)` rows and MySQL accepts every one. The NULL case, which is exactly the step-04 duplicate case, would remain unguarded by the very constraint meant to guard it.

So the column must be NOT NULL, with a sentinel for "no edge". The migration already established the sentinel: `2026_06_07_000002` backfilled everything to edge `R` (line 33). Use `R`, and only invent a distinct `NONE` edge if the business genuinely distinguishes "rectangular" from "edge not applicable" — ask before assuming.

```php
// After stage 3 has eliminated NULL-edge duplicates
$edgeId = DB::table('product_edges')->where('code', 'R')->value('id');
if (! $edgeId) {
    throw new \RuntimeException('R edge missing; 2026_06_07_000002 should have created it.');
}

DB::table('product_variants')->whereNull('product_edge_id')->update(['product_edge_id' => $edgeId]);

DB::statement('ALTER TABLE product_variants MODIFY product_edge_id BIGINT UNSIGNED NOT NULL');
```

The `MODIFY` fails if any NULL survives. Good — that means stage 3 was incomplete.

Then update `findOrCreate` so `$edgeId = null` resolves to the sentinel rather than `whereNull`. Otherwise the null path queries for a state that can no longer exist and creates nothing but errors. This is the code change that pairs with the NOT NULL, and forgetting it turns every legacy caller into a runtime failure.

### Stage 5 — The constraint

```php
Schema::table('product_variants', function (Blueprint $table) {
    $table->dropIndex('variants_color_size_idx');   // superseded
    $table->unique(
        ['product_color_id', 'product_size_id', 'product_edge_id'],
        'variants_color_size_edge_unique'
    );
});
```

`product_size_id` is still nullable (`2026_04_07_000003:28-31`), so `(12, NULL, 1)` remains unconstrained for the same MySQL reason. If size-less variants exist, they need the same sentinel treatment — check first:

```sql
SELECT COUNT(*) FROM product_variants WHERE product_size_id IS NULL;
```

If that is zero, make the column NOT NULL too and the constraint is total. If not, document the remaining hole rather than pretending it is closed.

Once the real constraint exists, `ProductVariantService::findOrCreate`'s `catch (UniqueConstraintViolationException)` block (lines 78-100) becomes meaningful for the first time — it will now catch violations of the *identity*, not of a derived string, and the fallback `SELECT` will find the right row. The `?? ProductVariant::where('sku_code', $sku)` fallback (line 99) can go: it exists only to paper over the SKU-format mismatch that stage 1 eliminated. Removing it is the point of the whole exercise. Do it in a follow-up commit so the constraint's effect is visible on its own.

## How to verify

No test suite. **Staging restored from a fresh production dump, every time.** Restore between attempts — a half-merged database is not a valid starting point for the next attempt.

**1. Record the baseline.** Before anything:

```sql
-- Total stock per variant, the number that must not change
SELECT product_variant_id,
       SUM(CASE WHEN movement_type = 'in'  THEN quantity ELSE 0 END)
     - SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END) AS stock
FROM stock_movements GROUP BY product_variant_id ORDER BY product_variant_id;
```

Dump that to a file. Also record `SELECT COUNT(*) FROM product_variants;` and the row counts of all five FK tables.

**2. Dry-run, and read every line.** `php artisan variants:merge-duplicates` with no `--force`. It must:
- Write nothing. Confirm: `SELECT COUNT(*) FROM product_variants;` unchanged, `product_variant_merges` empty.
- Report every group, the survivor, the losers, and the row counts that would move.
- Report the stock before/after per group. **Any group where they differ is a bug in the command — stop.**

Take the dry-run output to the office. Every `{NULL, R}` group needs a human "yes, same carpet". Every `{R, S}` group needs a "no, leave alone".

**3. Merge one group.** `--force --group=<one group>`. Then:

```sql
-- Total stock across the pair must be identical to the baseline sum
SELECT product_variant_id, ... FROM stock_movements
WHERE product_variant_id IN (<survivor>) GROUP BY product_variant_id;
-- must equal baseline(survivor) + baseline(loser)

SELECT * FROM product_variant_merges;   -- one row, snapshot populated
SELECT * FROM product_variants WHERE id = <loser>;   -- gone
SELECT COUNT(*) FROM stock_movements WHERE product_variant_id = <loser>;  -- 0
```

Repeat for all five FK tables. Then check the **grand total** across all variants is unchanged from the baseline file — the merge moves stock between IDs, it must never create or destroy any.

**4. Exercise the app against the merged variant.** This is the step that catches what SQL cannot:
- `GET /api/v1/stock` — the merged carpet appears **once**, with the combined quantity.
- `GET /api/v1/product-variants/barcode/{barcode}` — with the **survivor's** barcode, resolves. With the **loser's** barcode, now 404s. If that barcode is on a physical label, you have a problem — see stage 3.
- Drive the shipment-import wizard for a client with an order on the merged variant. `available_quantity` must reflect the combined stock.
- Create a warehouse `in` document for it. No new variant appears.

**5. Then the constraint.** After stages 4 and 5:

```sql
SHOW INDEX FROM product_variants WHERE Key_name = 'variants_color_size_edge_unique';
SELECT COUNT(*) FROM product_variants WHERE product_edge_id IS NULL;   -- must be 0
```

Prove it bites:

```sql
-- Must fail with a duplicate key error
INSERT INTO product_variants (product_color_id, product_size_id, product_edge_id, sku_code)
SELECT product_color_id, product_size_id, product_edge_id, CONCAT(sku_code, '-DUP')
FROM product_variants LIMIT 1;
```

If that succeeds, the constraint is not doing its job.

**6. Full application pass on staging.** Create an order, plan production, receive to warehouse, ship it, check the ledger. The whole chain, once, by hand. This step touched the identity every other table points at; a smoke test is not optional.

## Rollback

**Per stage. This is why they are separate deploys.**

| Stage | Rollback |
|---|---|
| 1 (SKU regen) | Restore `sku_code` from a pre-migration snapshot of `(id, sku_code)`. **Take that snapshot before you start** — it is two columns and it is your only way back. |
| 2 (find) | Read-only. Nothing to undo. |
| 3 (merge) | **Not cleanly reversible in code.** `product_variant_merges` has the snapshots and counts, so a reverse command is *possible* — reinsert the loser from `loser_snapshot`, repoint the counted rows back. But rows written *after* the merge cannot be attributed. In practice: **restore from backup.** |
| 4 (NOT NULL) | `ALTER TABLE product_variants MODIFY product_edge_id BIGINT UNSIGNED NULL`. Clean. The sentinel values stay, which is harmless. |
| 5 (constraint) | `DROP INDEX variants_color_size_edge_unique`, re-add the plain index. Clean and instant. |

**Before stage 3 touches production, take a full `mysqldump` and verify you can restore it.** Not "we have backups" — actually restore it to a scratch database and check the row counts. A backup you have not restored is a hope.

The realistic rollback plan for stage 3 is: stop writes, restore the dump, replay nothing. Which means stage 3 runs in a **maintenance window with the app in read-only or offline**, at a time the factory is not shipping. Agree that window before you write the command.

## Depends on / blocks

- **Depends on: step 04, absolutely.** Step 04 stops `WarehouseDocumentService` minting new NULL-edge variants. Merge before that ships and new duplicates appear behind you; add the constraint before it ships and warehouse documents start throwing `UniqueConstraintViolationException` in production. **Ship 04, watch the duplicate count stay flat for several days, then start here.**
- **Blocks:** phase-2's `product_variant_stock` balance row. A balance keyed on a non-unique identity is a balance for a carpet that exists twice. This must land first.
- **Sequence within this step:** 1 → 2 → 3 → 4 → 5, separate deploys, verified between each. Stage 3 needs a maintenance window and a signed-off duplicate list.
- **Do not start this in the same week as steps 01-03.** Those change money and stock readings. If a number looks wrong afterwards you need to know whether it was the merge or the rounding. Land 01-04, let them settle, then do this on its own.
