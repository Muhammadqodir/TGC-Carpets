# 07 — `product_variant_stock` balance row (STRUCT-2)

Stock is always a live `SUM` over `stock_movements` — correct, but unlockable. Add a balance row that can be `SELECT … FOR UPDATE`d, updated in the same transaction as every movement.

**Severity:** High — negative-stock races are structural today / **Effort:** 5 days / **Safe on live:** Yes, if the expand → dual-write → backfill → verify → switch sequence is followed exactly

## Why this matters

Every stock read in this system aggregates the ledger at query time. `WarehouseDocumentService::getStock()` (line 244):

```php
private function getStock(int $variantId): int
{
    $base = StockMovement::where('product_variant_id', $variantId);
    $in  = (clone $base)->where('movement_type', StockMovement::TYPE_IN)->sum('quantity');
    $out = (clone $base)->where('movement_type', StockMovement::TYPE_OUT)->sum('quantity');
    return (int) ($in - $out);
}
```

`StockController::index()` (lines 24–44) does it with correlated subqueries per product row, and `StockController::variants()` (line 91) does it per variant, alongside two more correlated subqueries (`qtyReceivedForActiveOrders` line 101, `qtyShippedForActiveOrders` line 110).

This is **correct** — the ledger is the truth and the sum is honest. It has two problems.

### 1. You cannot lock an aggregate — this is why stock goes negative

`assertSufficientStock()` (line 209) calls `getStock()` (line 225) and throws if there is not enough. Then `syncItems()` (line 133) inserts the movement. Between those two, nothing holds a lock — **because there is nothing to lock.** `SELECT SUM(...)` acquires no row lock you can rely on; there is no row that *represents* the balance.

Two concurrent OUT documents for the last 5 carpets:

| | Request A | Request B |
|---|---|---|
| t1 | `getStock()` → 5 | |
| t2 | | `getStock()` → 5 |
| t3 | 5 >= 5, passes | |
| t4 | | 5 >= 5, passes |
| t5 | `INSERT` OUT 5 | |
| t6 | | `INSERT` OUT 5 |

Stock is now **−5**. Ten carpets shipped, five existed. Both requests obeyed the rules. No error, no warning — `StockController::variants()` line 154 has `HAVING quantity_warehouse > 0`, so the variant simply **vanishes from the stock list** and nobody sees the negative at all.

Wrapping it in a transaction does not help: with no row to lock, both transactions read the same committed state and both commit. `SELECT … FOR UPDATE` needs a **row**. That is the fix — not a bigger transaction, a lockable row.

### 2. Every stock read is O(ledger)

`stock_movements` only grows. `GET /stock/variants` runs three correlated subqueries **per row returned**, each scanning that variant's whole movement history. The stock page gets slower every month, forever, and the work is entirely redundant — it recomputes the same historical sum on every request. A balance row makes it O(1) per row.

### The design

Same principle as `production_events`: **the ledger stays the source of truth; the balance is a cache written in the same transaction, and step 08 asserts they agree.** `stock_movements` is already a proper append-only log — unlike production, the log exists and is correct. What is missing is the lockable cache.

Do **not** delete or alter `stock_movements`. It is the thing the balance is checked against.

## Files to change

| File | Line | What is there now |
|---|---|---|
| `tgc_backend/database/migrations/` | new | create `product_variant_stock` |
| `tgc_backend/app/Models/ProductVariantStock.php` | new | model |
| `tgc_backend/app/Services/WarehouseDocumentService.php` | 244–257 | `getStock()` — the live SUM |
| ″ | 209–242 | `assertSufficientStock()` — calls `getStock()` at line 225, no lock |
| ″ | 133–175 | `syncItems()` — `StockMovement::create()` at line 161 |
| ″ | 177–207 | `reverseMovements()` — `StockMovement::create()` at line 193 |
| `tgc_backend/app/Http/Controllers/Api/V1/StockController.php` | 24–44 | `index()` — correlated subqueries per product |
| ″ | 91–96 | `variants()` — `qtyWarehouse` correlated subquery |
| `tgc_backend/app/Console/Commands/BackfillProductVariantStock.php` | new | backfill |

Other writers of `stock_movements` exist beyond `WarehouseDocumentService` — grep before you start:

```bash
grep -rn "StockMovement::create\|stock_movements" tgc_backend/app/ --include=*.php
```

**Every single writer must dual-write.** One missed path and the balance drifts silently, which is worse than the live SUM you replaced. This grep is the first task of this step, not an afterthought.

## The change

### 1. Migration (expand)

```php
Schema::create('product_variant_stock', function (Blueprint $table): void {
    // variant_id is the PRIMARY KEY — exactly one balance row per variant.
    $table->foreignId('product_variant_id')
          ->primary()
          ->constrained('product_variants')
          ->cascadeOnDelete();
    $table->integer('quantity')->default(0);   // signed: must be able to represent a negative
    $table->timestamps();
});
```

Two deliberate choices:

- **`product_variant_id` as the PK**, not an `id` + unique. One row per variant is the invariant; make the schema enforce it. It also makes the lock target the primary key.
- **`integer`, not `unsignedInteger`.** `production_batch_items` uses unsigned and it is a trap (see step 05). If stock is negative today — and it may well be, given the race — an unsigned column cannot represent it and the backfill will throw. You need to *see* negatives to fix them, not have the schema hide them.

### 2. Model

```php
class ProductVariantStock extends Model
{
    protected $table      = 'product_variant_stock';
    protected $primaryKey = 'product_variant_id';
    public    $incrementing = false;

    protected $fillable = ['product_variant_id', 'quantity'];
    protected function casts(): array
    {
        return ['quantity' => 'integer'];
    }
}
```

### 3. Dual-write (still no reader)

Every `StockMovement::create()` gets a balance update in the same transaction. Both call sites in `WarehouseDocumentService` — `syncItems()` line 161 and `reverseMovements()` line 193 — already run inside `DB::transaction` (lines 37, 66, 102).

Put it in one private helper so no call site can invent its own version:

```php
private function applyStockDelta(int $variantId, string $movementType, int $quantity): void
{
    $delta = $movementType === StockMovement::TYPE_IN ? $quantity : -$quantity;

    // Create-or-lock, then update. upsert() handles the first-ever movement for a variant.
    DB::table('product_variant_stock')->upsert(
        [['product_variant_id' => $variantId, 'quantity' => 0,
          'created_at' => now(), 'updated_at' => now()]],
        ['product_variant_id'],
        [],   // on conflict: change nothing, we only want the row to exist
    );

    DB::table('product_variant_stock')
        ->where('product_variant_id', $variantId)
        ->update([
            'quantity'   => DB::raw("quantity + ({$delta})"),
            'updated_at' => now(),
        ]);
}
```

`quantity = quantity + delta` in SQL, not read-modify-write in PHP — the database applies the delta atomically under its own row lock. Never `$row->quantity + $delta` in application code.

Call it immediately after each `StockMovement::create()`, inside the same transaction. Nothing reads the column yet — this deploy changes no behaviour.

### 4. Backfill

Same shape as step 03: an idempotent, chunked artisan command, not a migration.

```php
protected $signature = 'stock:backfill-balances {--chunk=500} {--dry-run}';

// For each variant: compute the ledger sum and upsert the balance.
ProductVariant::query()
    ->orderBy('id')
    ->chunkById($chunk, function ($variants) use ($dryRun): void {
        foreach ($variants as $variant) {
            $qty = (int) DB::table('stock_movements')
                ->where('product_variant_id', $variant->id)
                ->selectRaw('COALESCE(SUM(CASE WHEN movement_type = ? THEN quantity ELSE -quantity END), 0) AS q',
                            [StockMovement::TYPE_IN])
                ->value('q');

            if (! $dryRun) {
                DB::table('product_variant_stock')->upsert(
                    [['product_variant_id' => $variant->id, 'quantity' => $qty,
                      'created_at' => now(), 'updated_at' => now()]],
                    ['product_variant_id'],
                    ['quantity', 'updated_at'],   // recompute on re-run: idempotent
                );
            }
        }
    });
```

Re-runnable by construction — it recomputes from the ledger and overwrites, so running it twice is a no-op.

**The backfill must run while writes are paused, or it races the dual-write.** A movement landing between the `SUM` and the `upsert` gets counted by the sum and then applied again by the dual-write — double-counted. Options:

- **(Recommended)** Run it in a short maintenance window with the API in `php artisan down`. Factory hours are known; this is a small table.
- Or run it, then immediately run step 08's reconcile with `--fix` to correct anything that raced. Acceptable only if you accept a brief window of wrong balances — and remember nothing reads them yet, so the exposure is genuinely zero until step 6 below.

### 5. Switch the lock target — the actual fix

Only after the backfill verifies clean. `assertSufficientStock()` (line 209) currently reads with no lock. Restructure so the check and the insert are one locked unit:

```php
// Inside the same DB::transaction as the movement insert:
$row = DB::table('product_variant_stock')
    ->where('product_variant_id', $variantId)
    ->lockForUpdate()          // ← the whole point: a real row, a real lock
    ->first();

$currentStock = (int) ($row->quantity ?? 0);

if ($currentStock < $requestedQty) {
    throw ValidationException::withMessages([...]);
}

// insert movement + applyStockDelta(), still holding the lock
```

Now request B blocks at `lockForUpdate()` until A commits, then reads **0** and correctly fails. The race is gone — not narrowed, gone.

Ordering notes that matter:

- **`assertSufficientStock()` is currently called *before* the transaction body in `create()`** (line 39, inside the transaction closure — check `update()` at line 77 too). The lock must be taken inside the same transaction that inserts the movement, or it is released too early and the race returns.
- **Lock variants in a deterministic order** (sort by `product_variant_id`) when a document touches several. Two documents with the same variants in different orders will deadlock otherwise. This is a real risk — warehouse documents routinely have many lines.
- **A missing row means zero.** `->first()` returns null for a variant that has never moved. `?? 0` handles it, but for an OUT document that is correctly a rejection. Consider upserting the row before locking so the lock always has a target.

### 6. Switch the reads (last)

Only after the balance has been verified correct for days.

`getStock()` (line 244) collapses to:

```php
private function getStock(int $variantId): int
{
    return (int) DB::table('product_variant_stock')
        ->where('product_variant_id', $variantId)
        ->value('quantity') ?? 0;
}
```

`StockController::variants()` — replace the `qtyWarehouse` correlated subquery (lines 91–96) with a join:

```php
->leftJoin('product_variant_stock as pvs', 'pvs.product_variant_id', '=', 'product_variants.id')
->addSelect('pvs.quantity as quantity_warehouse')
```

and drop the `->selectSub($qtyWarehouse, 'quantity_warehouse')` at line 135. The `HAVING quantity_warehouse > 0` at line 154 becomes a `WHERE pvs.quantity > 0` — cheaper, and index-usable.

`StockController::index()` (lines 24–44) aggregates per **product**, not per variant, so it becomes a join through `product_variants` → `product_colors` summing `pvs.quantity`. Note it currently reports `stock_in` and `stock_out` separately (lines 63–64) — the balance row does not carry that split. Either keep those two subqueries (they are the honest source for a lifetime in/out figure) and take only `current_stock` from the balance, or agree with the owner that the split is dropped. **Do not silently change what those fields mean.**

Leave `qtyReceivedForActiveOrders` (line 101) and `qtyShippedForActiveOrders` (line 110) alone — they aggregate different tables and are out of scope. This step is about `quantity_warehouse` only.

## How to verify

No test suite. Staging, with a production-shaped dataset.

1. **Find existing negatives before you start.** This tells you whether the race has already fired on live:
   ```sql
   SELECT product_variant_id,
          SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END) AS qty
   FROM stock_movements GROUP BY product_variant_id HAVING qty < 0;
   ```
   Any row here is a carpet shipped that never existed. Take the list to the owner — the balance row will now make these visible rather than hiding them behind `HAVING quantity_warehouse > 0`.
2. **Backfill matches the ledger, exactly:**
   ```sql
   SELECT s.product_variant_id, s.quantity AS balance, m.qty AS ledger
   FROM product_variant_stock s
   LEFT JOIN (
       SELECT product_variant_id,
              SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END) AS qty
       FROM stock_movements GROUP BY product_variant_id
   ) m ON m.product_variant_id = s.product_variant_id
   WHERE s.quantity <> COALESCE(m.qty, 0);
   ```
   **Zero rows.** This is step 08's query — build it here, formalise it there.
3. **Dual-write keeps them equal.** Create an IN document via the app for a known variant, then re-run #2 → still zero rows, and the balance moved by the document's quantity. Repeat for OUT, for `return`, for `adjustment` — all four map through the `match` at lines 154–159 and every one must dual-write. Then **delete** a document (`WarehouseDocumentService::delete()` line 100 → `reverseMovements()` line 177) and confirm the balance comes back. Reversal is the path most likely to be missed.
4. **The race is actually fixed** — the reason this step exists:
   - Set a variant's stock to exactly 5.
   - Fire two OUT documents for 5 each, simultaneously:
     ```bash
     for i in 1 2; do
       curl -X POST https://<host>/api/v1/warehouse-documents \
         -H "Authorization: Bearer <TOKEN>" -H "Content-Type: application/json" \
         -d '{"type":"out","document_date":"2026-07-14","items":[{"product_color_id":<PC>,"product_size_id":<PS>,"quantity":5}]}' &
     done; wait
     ```
   - **Exactly one must succeed**; the other must get a 422 insufficient-stock error. Confirm the balance is 0, not −5.
   - **Run this against the current code first and watch it produce −5.** If you cannot reproduce the bug before the fix, you have not proven the fix does anything.
5. **Deadlock check.** Two documents with the same three variants in **opposite line order**, fired concurrently, repeatedly (20+ times). No deadlock errors in `storage/logs/laravel.log`. If you see `Deadlock found when trying to get lock`, the deterministic lock ordering is missing.
6. **Performance, measured.** Before and after switching reads, time:
   ```bash
   time curl -s "https://<host>/api/v1/stock/variants?per_page=50" -H "Authorization: Bearer <TOKEN>" -o /dev/null
   ```
   Expect a clear improvement on a large ledger. `EXPLAIN` the new query — the correlated subquery on `stock_movements` must be gone from the plan.
7. **Read parity before the switch.** Run both old and new reads over every variant and diff:
   ```sql
   -- must return zero rows (same query as #2, run against live data before switching reads)
   ```
   Do not switch reads on a balance you have not diffed against the ledger across the **whole table**, not a sample.
8. **Watch reconcile for a week** (step 08) before switching reads. Drift during dual-write means a writer was missed — find it before anyone depends on the number.

## Rollback

Sequenced, and each stage is independently reversible — which is the reason for the sequence.

- **Reads switched (step 6):** revert `getStock()` and `StockController` to the live SUM. The ledger never stopped being the truth, so this is instant and lossless. **This is your escape hatch — the live SUM is always correct.**
- **Lock target switched (step 5):** revert `assertSufficientStock()`. You are back to the race, which is where you started. No data harm.
- **Dual-write (step 3):** revert. The balance stops updating and goes stale. Harmless while nothing reads it; if reads have switched, revert those **first**.
- **Schema:** `migrate:rollback` drops `product_variant_stock`. Only do this once no code references it.
- **Never roll back by "fixing" `stock_movements`.** The ledger is correct. If the balance disagrees, the balance is wrong. Always.

Rollback order is the reverse of rollout: reads → lock → dual-write → schema.

## Depends on / blocks

- **Depends on:** nothing in this phase. **07 and 08 are fully independent of 01–06** and can be worked in parallel by a second developer.
- **Blocks: 08** — the reconcile command needs the table to assert against.
- **Blocked by nothing, but do not rush it.** 5 days is the estimate because of the five-stage sequence, not because the code is hard. The code is a day. The sequence is what keeps the factory shipping.
- Related and explicitly **out of scope**: `WarehouseDocumentService::creditProductionBatchItems()` (line 264) and `debitProductionBatchItems()` (line 291) already use `lockForUpdate()` on `production_batch_items` — they are a different counter with a different problem, and step 05 touches their invariants. Do not fold them into this step.
