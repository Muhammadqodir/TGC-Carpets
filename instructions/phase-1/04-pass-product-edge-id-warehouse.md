# 04 — Pass `product_edge_id` when resolving variants in `WarehouseDocumentService`

`WarehouseDocumentService` calls `findOrCreate()` without the edge argument while every other caller passes it. Because all existing variants were backfilled with edge `R`, the omission never matches and silently creates a duplicate variant, splitting stock across two IDs.

**Severity: High / Effort: 1d / Safe on live: Yes. Must ship before step 05.**

## Why this matters

`ProductVariantService::findOrCreate` has three parameters (`app/Services/ProductVariantService.php:28`):

```php
public function findOrCreate(int $productColorId, ?int $sizeId, ?int $edgeId = null): ProductVariant
```

`$edgeId` defaults to `null`, and the lookup treats `null` as **"the variant whose edge is NULL"**, not as "any edge" (lines 37-41):

```php
->when(
    $edgeId !== null,
    fn ($q) => $q->where('product_edge_id', $edgeId),
    fn ($q) => $q->whereNull('product_edge_id'),      // ← this branch
)
```

Now the migration. `database/migrations/2026_06_07_000002_*` added the column and backfilled **every** existing row (line 33):

```php
// Backfill all existing variants with the 'R' edge
DB::table('product_variants')->whereNull('product_edge_id')->update(['product_edge_id' => $edgeId]);
```

So after that migration, **no variant has a NULL edge**. `whereNull('product_edge_id')` matches nothing, ever.

Two of three callers pass the edge. One does not:

| Caller | Line | Passes edge? |
|---|---|---|
| `app/Services/OrderService.php` | 89-93 | **Yes** — `$itemData['product_edge_id'] ?? null` |
| `app/Services/ProductionBatchService.php` | 256-260 | **Yes** — `!empty($itemData['product_edge_id']) ? (int) ... : null` |
| `app/Services/WarehouseDocumentService.php` | 136-139 | **No** — third argument omitted |

The failure, concretely. An order exists for product colour 12, size 4, edge `R` (id 1) → variant **77**, holding all the stock movements. A warehouse document arrives for the same physical carpet:

1. `syncItems` calls `findOrCreate(12, 4)` — edge defaults to `null`.
2. Fast path queries `product_color_id=12 AND product_size_id=4 AND product_edge_id IS NULL` → **no match**, because variant 77 has edge 1.
3. So it creates a new variant, **91**, with `product_edge_id = NULL`.
4. The `WarehouseDocumentItem` (lines 141-147) and `StockMovement` (lines 161-169) are written against **91**.

Stock for one physical carpet is now split across two variant IDs. Variant 77 holds the order and its shipments; variant 91 holds whatever came through the warehouse. Every stock reading is wrong: `StockController` lists both as separate rows, `ShipmentImportController`'s `STOCK_SUB` (lines 30-33) finds the goods under 91 while the order points at 77, and the warehouse's own `assertSufficientStock` reports zero for a shelf that is full.

Step 3 does not always create a *new* row. `ProductVariant::create` may collide on the `sku_code` unique index — `generateSku` is called with `$edge?->code` = null (line 59), which for a size-bearing variant produces the same SKU as the `R` variant only if the `R` variant's SKU also lacks the `-E` suffix. Whether it collides depends on when that variant's SKU was generated. The `catch (UniqueConstraintViolationException)` block (lines 78-100) then falls back to `ProductVariant::where('sku_code', $sku)` and may return the **correct** variant 77 after all. So the bug is **intermittent** — it depends on each variant's SKU history. That is worse than a consistent failure, not better: it means some products split and some do not, and nobody can predict which.

This is also why step 05 cannot go first. Adding a unique constraint on `(color, size, edge)` while this code is still creating NULL-edge rows would either fail on existing duplicates or start throwing at runtime. **Fix the producer before you constrain the data.**

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | What |
|---|---|---|
| `app/Services/WarehouseDocumentService.php` | 133-139 | `syncItems` — pass the edge. |
| `app/Services/WarehouseDocumentService.php` | 209-242 | `assertSufficientStock` — **same bug**, also ignores edge. |
| `app/Http/Requests/WarehouseDocument/StoreWarehouseDocumentRequest.php` | — | Check whether `product_edge_id` is accepted. |
| `app/Http/Requests/WarehouseDocument/UpdateWarehouseDocumentRequest.php` | — | Same. |

## The change

### 1. `syncItems`

```php
// current — lines 136-139
$variant = $this->variantService->findOrCreate(
    $itemData['product_color_id'],
    $itemData['product_size_id'] ?? null,
);

// intended
$variant = $this->variantService->findOrCreate(
    $itemData['product_color_id'],
    $itemData['product_size_id'] ?? null,
    $itemData['product_edge_id'] ?? null,
);
```

Match `OrderService`'s form (lines 89-93) rather than `ProductionBatchService`'s `!empty()` form. `!empty()` treats `0` as absent, which is fine for an ID that is never 0, but `?? null` says what it means.

### 2. `assertSufficientStock` — the same omission, same file

Lines 217-223 resolve the variant for the stock check and also ignore the edge:

```php
// current — lines 217-223
$variant = ProductVariant::where('product_color_id', $productColorId)
    ->when(
        $sizeId !== null,
        fn ($q) => $q->where('product_size_id', $sizeId),
        fn ($q) => $q->whereNull('product_size_id'),
    )
    ->first();
```

No edge filter at all — so this one has the *opposite* failure: `->first()` picks an arbitrary variant among all edges for that colour and size. The check and the write can therefore resolve to **different variants**: `assertSufficientStock` validates stock on variant 77 while `syncItems` writes to variant 91. The document is accepted on one balance and applied to another.

```php
// intended — lines 213-225
foreach ($items as $index => $itemData) {
    $productColorId = $itemData['product_color_id'];
    $sizeId         = $itemData['product_size_id'] ?? null;
    $edgeId         = $itemData['product_edge_id'] ?? null;

    $variant = ProductVariant::where('product_color_id', $productColorId)
        ->when(
            $sizeId !== null,
            fn ($q) => $q->where('product_size_id', $sizeId),
            fn ($q) => $q->whereNull('product_size_id'),
        )
        ->when(
            $edgeId !== null,
            fn ($q) => $q->where('product_edge_id', $edgeId),
            fn ($q) => $q->whereNull('product_edge_id'),
        )
        ->first();

    $currentStock = $variant ? $this->getStock($variant->id) : 0;
```

The `->when()` shape now mirrors `findOrCreate` exactly, so check and write resolve identically. If you extend the error message at lines 233-235 to name the edge, keep it optional — `$edgeId` may legitimately be null on a payload that predates this change.

**Do not fix the non-accumulating loop here.** `WarehouseDocumentService::assertSufficientStock` has the same per-line re-read bug as `ShipmentService` (step 03), and the same `getStock` duplication (lines 244-257). Both are real. Neither is this step. Keep this change to the edge argument so the diff is reviewable and the rollback is trivial.

### 3. Confirm the payload carries `product_edge_id`

The service change is inert if the request never accepts the field. Read `StoreWarehouseDocumentRequest` and `UpdateWarehouseDocumentRequest` before you start:

```bash
grep -n 'product_edge_id\|product_size_id\|product_color_id' \
  app/Http/Requests/WarehouseDocument/*.php
```

If `items.*.product_edge_id` is absent from `rules()`, add it alongside the existing size rule:

```php
'items.*.product_edge_id' => ['nullable', 'integer', 'exists:product_edges,id'],
```

Then check whether the **client** actually sends it. Grep the Flutter app under `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_client` for the warehouse document payload. If the client does not send an edge, this change resolves every warehouse item to `whereNull('product_edge_id')` — which after the `R` backfill matches nothing, so `findOrCreate` still creates NULL-edge duplicates and **you have fixed nothing**.

That is the crux of this step. Work out which of these you are in before writing code:

- **Client sends `product_edge_id`** → the service change is the whole fix. Ship it.
- **Client does not send it** → the server has no way to know the edge, and passing `null` is honest but useless. You need the client to send it, *or* a documented server-side default. If you default, default to the **`R` edge the migration used** — not to null:

```php
// Only if the client genuinely cannot send an edge. Document why.
$edgeId = $itemData['product_edge_id']
    ?? ProductEdge::where('code', 'R')->value('id');
```

A null-edge default guarantees duplicates. An `R` default matches the backfilled reality and is at worst wrong for genuinely non-`R` carpets — which the UI should then be fixed to specify. Do not ship the null default and call it done.

## How to verify

No test suite. Staging, restored from a production dump.

**1. Measure the damage first.** This is the query that shows whether the bug has already fired in production. Run it against **production** before you touch anything:

```sql
SELECT product_color_id, product_size_id,
       COUNT(*)                                              AS variant_count,
       GROUP_CONCAT(id ORDER BY id)                          AS variant_ids,
       GROUP_CONCAT(COALESCE(product_edge_id, 'NULL') ORDER BY id) AS edges,
       GROUP_CONCAT(sku_code ORDER BY id SEPARATOR ' | ')    AS skus
FROM product_variants
GROUP BY product_color_id, product_size_id
HAVING COUNT(*) > 1
ORDER BY variant_count DESC;
```

Every group containing a `NULL` edge alongside a real one is a split caused by this bug. Save the output — **step 05 needs exactly this list**, and it is the evidence for how much stock is currently mis-attributed.

Then find NULL-edge variants that carry stock, which is the sharp end:

```sql
SELECT pv.id, pv.product_color_id, pv.product_size_id, pv.sku_code,
       COALESCE(SUM(CASE WHEN sm.movement_type = 'in'  THEN sm.quantity ELSE 0 END), 0)
     - COALESCE(SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END), 0) AS stock
FROM product_variants pv
LEFT JOIN stock_movements sm ON sm.product_variant_id = pv.id
WHERE pv.product_edge_id IS NULL
GROUP BY pv.id, pv.product_color_id, pv.product_size_id, pv.sku_code;
```

Any row with non-zero stock is real inventory sitting under a phantom variant.

**2. Reproduce the bug before fixing it.** On staging, note `SELECT MAX(id) FROM product_variants`. Post a warehouse `in` document for a colour/size that already has an `R`-edge variant:

```bash
curl -X POST https://staging/api/v1/warehouse-documents \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"type": "in", "document_date": "2026-07-14",
       "items": [{"product_color_id": <pc>, "product_size_id": <ps>, "quantity": 5}]}'
```

Then:

```sql
SELECT id, product_color_id, product_size_id, product_edge_id, sku_code
FROM product_variants WHERE id > <previous max>;
```

- **Before the change:** you should see a **new** variant with `product_edge_id IS NULL`. That is the bug, reproduced.
- If you see *no* new row, this payload hit the `sku_code` collision path (lines 78-100) and was rescued. Try a different colour/size — the intermittency described above is exactly what you are seeing. Find one that splits.

**3. After the change**, repeat with the edge supplied:

```bash
  -d '{"type": "in", "document_date": "2026-07-14",
       "items": [{"product_color_id": <pc>, "product_size_id": <ps>,
                  "product_edge_id": <the R edge id>, "quantity": 5}]}'
```

No new variant row. The stock movement must land on the **existing** variant:

```sql
SELECT sm.product_variant_id, sm.quantity, sm.movement_type
FROM stock_movements sm ORDER BY sm.id DESC LIMIT 5;
-- product_variant_id must be the pre-existing R variant, not a new ID
```

**4. Confirm the check and the write agree.** Post a document for a colour/size where the `R` variant has **insufficient** stock for an `out` document. It must be rejected on the `R` variant's balance. Before the fix, `assertSufficientStock`'s `->first()` might have validated against a different variant entirely — after the fix it cannot.

**5. Drive the real UI.** Create a warehouse document through the client app on staging, both `in` and `out`. Then re-run the duplicate query from step 1 — **the count must not have grown**. This is the acceptance criterion: normal use of the app stops minting duplicates.

**6. Watch production after deploy.** Re-run the step-1 duplicate query daily for a few days. The number of `(colour, size)` groups containing a NULL edge must be **flat**. If it grows, the client is not sending `product_edge_id` and you are in the second case from section 3.

## Rollback

Pure code change, no migration. `git revert` and deploy.

Rollback is safe but **not clean in effect**: any duplicate variants created while the fix was live are correct rows that stay correct, and reverting resumes creating new duplicates. Nothing to undo, but the reason for the revert had better be a good one.

Note that this step does **not** repair existing duplicates. Splits already in the database stay split until step 05 merges them. Shipping this alone stops the bleeding; it does not heal anything.

## Depends on / blocks

- **Depends on:** nothing.
- **Blocks: step 05, absolutely.** Step 05 merges duplicate variants and adds `unique(product_color_id, product_size_id, product_edge_id)`. Merging while this bug is live means new duplicates appear between the merge and the constraint, and the constraint's `ALTER TABLE` fails. Worse, if the constraint somehow lands first, `findOrCreate(…, null)` starts throwing `UniqueConstraintViolationException` on the NULL-edge insert and warehouse documents begin failing in production.

  **Ship 04, verify the duplicate count is flat for several days, then start 05.** Do not compress this.
- **Related:** the duplicate list from verification step 1 is step 05's input. Produce it properly and hand it over.
