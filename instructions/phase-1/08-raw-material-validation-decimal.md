# 08 — Raw material stock: validate it, store it as decimal, and delete it cleanly

`RawMaterialStockService` has no stock validation at all — spending 1000 kg you do not have is accepted. Quantities are stored as `double` and cast to `float`, so kg and m² sums drift. And deleting a raw material with movements throws a raw `QueryException`.

**Severity: Medium-High / Effort: 1d / Safe on live: Mostly — the validation half needs the same care as step 02.**

## Why this matters

### There is no stock check. None.

`app/Services/RawMaterialStockService.php` is 40 lines, and this is all of `storeBatch` (lines 15-39):

```php
public function storeBatch(array $data, int $userId): array
{
    return DB::transaction(function () use ($data, $userId): array {
        $movements = [];

        foreach ($data['items'] as $item) {
            $movements[] = RawMaterialStockMovement::create([
                'material_id' => $item['material_id'],
                'user_id'     => $userId,
                'date_time'   => $data['date_time'],
                'type'        => $data['type'],
                'quantity'    => $item['quantity'],
                'notes'       => $data['notes'] ?? null,
            ]);
        }
        // ... eager-load and return
    });
}
```

It writes what it is given. There is no read of the current balance, no comparison, no rejection path. Compare `ShipmentService` (`assertSufficientStock`, lines 404-423) and `WarehouseDocumentService` (lines 209-242) — both at least *attempt* a check, however flawed. The raw material path does not attempt one.

And the request does not compensate. `app/Http/Requests/RawMaterial/StoreBatchMovementRequest.php:24`:

```php
'items.*.quantity' => ['required', 'numeric', 'min:0.001'],
```

`min:0.001` means "greater than zero". That is the only constraint on the number.

So: a material with **0 kg** on hand accepts `type: "spent"`, `quantity: 1000`. The API returns 201. The balance is now **-1000 kg**. Nothing warns anyone. `RawMaterialStockMovement::TYPES` (line 13) is `['received', 'spent']`, and `spent` is accepted unconditionally regardless of what was ever received.

The balance is a sum over movements — the same pattern as `stock_movements` — so nothing at the schema level prevents a negative either. A factory can spend yarn it never bought and the system agrees.

### `double` for a quantity that gets summed

`database/migrations/2026_04_22_000002_*:21`:

```php
$table->double('quantity');
```

And `app/Models/RawMaterialStockMovement.php:28`:

```php
'quantity'  => 'float',
```

Binary floating point, in a column whose entire purpose is to be summed. Materials are measured in kg, sqm, meters and pieces — `RawMaterial::UNITS` (line 16) is `['piece', 'sqm', 'kg', 'meter']`. Three of those four are fractional in practice.

The classic failure: 0.1 + 0.2 ≠ 0.3 in binary floating point. Sum a few thousand movements of 12.5 kg, 0.3 kg, 7.25 kg and the total drifts from the arithmetic truth. `SUM()` over a `DOUBLE` column compounds it, and the error depends on **row order** — so the same query can return a different total after an index change. There is no rounding to hide behind here, unlike step 01: nobody rounds raw material weights to 2dp, so the drift accumulates unbounded.

`decimal(12,3)` is the right type: exact base-10, three decimals (grams for kg, mm for meters), and 12 digits of headroom. Note that `payments.amount` is already `decimal(14,2)` (`create_payments_table:16`) — the codebase knows the right answer for money and did not apply it here.

### `destroy` throws a raw QueryException

`app/Http/Controllers/Api/V1/RawMaterialController.php:104-109`:

```php
public function destroy(RawMaterial $rawMaterial): JsonResponse
{
    $rawMaterial->delete();

    return response()->json(['message' => 'Raw material deleted.']);
}
```

`raw_material_stock_movements.material_id` is `restrictOnDelete` (`2026_04_22_000002:13-15`). So deleting a material that has ever moved throws an unhandled `Illuminate\Database\QueryException` → **500 Internal Server Error**, with a MySQL foreign key message.

The FK is doing its job — that material *should not* be deletable. The bug is the presentation: a foreseeable, correct rejection is reported as a server crash. The user sees "something went wrong" instead of "this material has stock history and cannot be deleted". `RawMaterial` has no `SoftDeletes` (verified: only `Product` and `Client` use it), so there is no soft path either.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | What |
|---|---|---|
| `app/Services/RawMaterialStockService.php` | 15-39 | Add the balance check. |
| `app/Http/Requests/RawMaterial/StoreBatchMovementRequest.php` | 24 | Bound the decimal precision. |
| `database/migrations/` | new | `double` → `decimal(12,3)`. |
| `app/Models/RawMaterialStockMovement.php` | 28 | `float` → `decimal:3`. |
| `app/Http/Controllers/Api/V1/RawMaterialController.php` | 104-109 | `destroy` → 409. |

## The change

### 1. The stock check

Model it on `ShipmentService` after step 03 — aggregate per material, check inside the transaction, take a lock. Do not reproduce the per-line non-accumulating bug step 03 exists to fix.

```php
use App\Models\RawMaterial;
use Illuminate\Validation\ValidationException;

public function storeBatch(array $data, int $userId): array
{
    return DB::transaction(function () use ($data, $userId): array {
        if ($data['type'] === RawMaterialStockMovement::TYPE_SPENT) {
            $this->assertSufficientStock($data['items']);
        }

        $movements = [];
        // ... unchanged
    });
}

/**
 * @param  array<int, array{material_id: int, quantity: string|float}>  $items
 */
private function assertSufficientStock(array $items): void
{
    // Aggregate per material FIRST: two lines of the same material must be
    // checked against their combined total, not each against the full balance.
    $requestedPerMaterial = [];
    $lineIndexes          = [];

    foreach ($items as $index => $item) {
        $id = (int) $item['material_id'];
        $requestedPerMaterial[$id] = bcadd(
            $requestedPerMaterial[$id] ?? '0',
            (string) $item['quantity'],
            3
        );
        $lineIndexes[$id][] = $index;
    }

    // Stable lock order to avoid deadlocks between concurrent batches.
    $materialIds = array_keys($requestedPerMaterial);
    sort($materialIds);

    RawMaterial::whereIn('id', $materialIds)->orderBy('id')->lockForUpdate()->get();

    $errors = [];

    foreach ($requestedPerMaterial as $materialId => $requested) {
        $balance = $this->getBalance($materialId);

        if (bccomp($balance, $requested, 3) < 0) {
            $material   = RawMaterial::find($materialId);
            $unit       = $material?->unit ?? '';
            $firstIndex = $lineIndexes[$materialId][0];

            $errors["items.{$firstIndex}.quantity"] = [
                sprintf(
                    'Insufficient stock for %s. Available: %s %s, Requested: %s %s.',
                    $material?->name ?? "material #{$materialId}",
                    $balance, $unit, $requested, $unit
                ),
            ];
        }
    }

    if (! empty($errors)) {
        throw ValidationException::withMessages($errors);
    }
}

private function getBalance(int $materialId): string
{
    $row = DB::table('raw_material_stock_movements')
        ->where('material_id', $materialId)
        ->selectRaw(
            "COALESCE(SUM(CASE WHEN type = 'received' THEN quantity ELSE 0 END), 0)"
            . " - COALESCE(SUM(CASE WHEN type = 'spent' THEN quantity ELSE 0 END), 0) AS balance"
        )
        ->first();

    return (string) ($row->balance ?? '0');
}
```

Points worth being deliberate about:

- **`bcadd` / `bccomp`, not float comparison.** Comparing balances with `<` on floats is how you reject a spend of exactly the available amount. bcmath is enabled here (verified). This only works properly once the column is `decimal` — see stage 2 and the ordering note below.
- **The lock is on `raw_materials`, a proxy** — same compromise as step 03, same reasoning, same caveat: it only serialises writers who take it. Since `RawMaterialStockService::storeBatch` is the only writer, that is currently total. Say so in a comment, because it stops being true the moment a second writer appears.
- **Only check on `spent`.** A `received` movement adds stock and needs no balance check.

### The same log-only rollout as step 02

**The live app may already be posting spends that exceed the balance** — that is exactly what an unvalidated endpoint plus a factory floor produces, and the negative balances in verification step 1 will tell you whether it does. If you enforce blind and the raw warehouse starts getting 422s mid-shift, you have stopped production over a bug that has been quietly tolerated for months.

Use the same flag pattern:

```php
// config/raw_materials.php
return [
    'enforce_stock_validation' => env('RAW_MATERIALS_ENFORCE_STOCK_VALIDATION', false),
];
```

...with `assertSufficientStock` logging `raw_material.validation.would_reject` and returning instead of throwing when the flag is off. Run log-only for a week, read every hit, then flip. See `02-validate-shipment-items.md` for the full pattern and the reasoning — it applies here unchanged.

If verification step 1 shows **zero** negative balances in production, the risk is much lower and you may reasonably enforce directly. Check before deciding.

### 2. `double` → `decimal(12,3)`

```php
// New migration
public function up(): void
{
    DB::statement(
        'ALTER TABLE raw_material_stock_movements MODIFY quantity DECIMAL(12,3) NOT NULL'
    );
}

public function down(): void
{
    DB::statement('ALTER TABLE raw_material_stock_movements MODIFY quantity DOUBLE NOT NULL');
}
```

Use raw `ALTER`, not `$table->decimal(...)->change()` — Laravel's `change()` needs `doctrine/dbal`, which is not in `composer.json` (verified: the `require` block is php, dompdf, framework, sanctum, tinker, phpspreadsheet). The rest of this codebase already uses raw `ALTER` for type changes: `2026_04_07_000006:44`, `2026_04_07_000007:50`. Follow that.

**`double` → `decimal(12,3)` rounds existing values to 3dp.** Check what that will do before running it:

```sql
-- Values with more than 3 decimals, which the ALTER will round
SELECT id, material_id, quantity
FROM raw_material_stock_movements
WHERE quantity <> ROUND(quantity, 3);

-- How much total drift the rounding introduces, per material
SELECT material_id,
       SUM(quantity)            AS current_sum,
       SUM(ROUND(quantity, 3))  AS after_sum,
       SUM(quantity) - SUM(ROUND(quantity, 3)) AS drift
FROM raw_material_stock_movements
GROUP BY material_id
HAVING ABS(drift) > 0.0005;
```

If the first query returns rows, real values change. That is almost certainly *fixing* float noise rather than losing data — a hand-entered 12.5 kg stored as 12.499999999999998 becoming 12.500 is the point. But **run it and look** rather than assuming, and if any material has meaningful drift, take it to the office before the ALTER.

Also check for values exceeding `DECIMAL(12,3)`'s range — 9 integer digits:

```sql
SELECT id, quantity FROM raw_material_stock_movements WHERE ABS(quantity) >= 1000000000;
```

Non-empty means the ALTER will fail or truncate. Widen the type rather than truncating.

**This ALTER locks the table.** It rewrites every row. On a large table that is minutes of blocked writes. Check the size first:

```sql
SELECT COUNT(*) FROM raw_material_stock_movements;
```

If it is large, run it in a maintenance window or use an online schema change tool. Do not run a rewriting ALTER on a live factory table at 10am without knowing the row count.

Then the model (line 28):

```php
// current
'quantity'  => 'float',

// intended
'quantity'  => 'decimal:3',
```

`decimal:3` returns a **string**, which is what you want — it is what keeps the value out of float arithmetic on the way back out. This will change the JSON response shape: `12.5` becomes `"12.500"`. **Check the Flutter client** at `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_client` for how it parses `quantity` on raw material movements. If it expects a JSON number and gets a string, the screen breaks. Find out before deploying — this is the most likely way this step causes an outage, and it has nothing to do with the interesting part of the change.

### 3. Bound the request precision

```php
// current — line 24
'items.*.quantity' => ['required', 'numeric', 'min:0.001'],

// intended
'items.*.quantity' => ['required', 'numeric', 'min:0.001', 'max:999999999', 'decimal:0,3'],
```

`decimal:0,3` rejects more than 3 decimal places at the door rather than silently rounding them in the database. `max` keeps the value inside `DECIMAL(12,3)`.

Consider whether `decimal:0,3` will reject payloads the client currently sends — a UI that computes a quantity and posts `12.500000001` would now 422. Grep the client. If in doubt, ship the `max` now and the `decimal` rule behind the same flag as the stock check.

### 4. `destroy` → 409

```php
// intended — replaces lines 104-109
public function destroy(RawMaterial $rawMaterial): JsonResponse
{
    if ($rawMaterial->stockMovements()->exists()) {
        return response()->json([
            'message' => 'Bu xomashyoni o\'chirib bo\'lmaydi: unda ombor harakatlari mavjud.',
        ], 409);
    }

    try {
        $rawMaterial->delete();
    } catch (\Illuminate\Database\QueryException $e) {
        // Belt and braces: another FK, or a movement created between the
        // check above and the delete.
        return response()->json([
            'message' => 'Bu xomashyoni o\'chirib bo\'lmaydi: u boshqa yozuvlarda ishlatilmoqda.',
        ], 409);
    }

    return response()->json(['message' => 'Raw material deleted.']);
}
```

`RawMaterial::stockMovements()` already exists (`app/Models/RawMaterial.php:22-25`).

Both the check and the `catch` — the check gives a good message, the `catch` closes the race between checking and deleting. The FK stays as the real guard; this only stops it surfacing as a 500.

User-facing messages elsewhere in this codebase are in Uzbek (see `EnsureWebAdmin.php:25`), so match that. Confirm the convention rather than copying my guess.

**409 or 422?** 409 Conflict is the better fit — the request is well-formed, the resource's state forbids it. Check what the client app expects; if it only handles 422, use 422 and note the compromise.

## How to verify

No test suite. Staging, restored from a production dump.

**1. Find existing negatives — run against production first.**

```sql
SELECT rm.id, rm.name, rm.unit,
       COALESCE(SUM(CASE WHEN m.type = 'received' THEN m.quantity ELSE 0 END), 0)
     - COALESCE(SUM(CASE WHEN m.type = 'spent'    THEN m.quantity ELSE 0 END), 0) AS balance
FROM raw_materials rm
LEFT JOIN raw_material_stock_movements m ON m.material_id = rm.id
GROUP BY rm.id, rm.name, rm.unit
HAVING balance < 0
ORDER BY balance;
```

Every row is a material the factory has spent more of than it ever received. **This decides your rollout.** Empty → enforce directly. Non-empty → log-only for a week, and the list is also a real question for the office: either the receipts were never entered, or the spends are wrong.

**2. Reproduce the missing check.** Find a material with a zero or small balance and post a spend far exceeding it:

```bash
curl -X POST https://staging/api/v1/raw-materials/movements/batch \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"date_time": "2026-07-14T10:00:00Z", "type": "spent",
       "items": [{"material_id": <id>, "quantity": 1000}]}'
```

**Confirm the route first** — `grep -n 'raw-material' routes/api.php` — I have not verified the batch movement path and will not guess it.

- **Before:** 201, balance goes to -1000.
- **After (enforcing):** 422 naming the material, its unit, and the available quantity. Balance unchanged, `SELECT MAX(id) FROM raw_material_stock_movements` unchanged.

**3. The aggregation case.** Balance 10 kg, one request with **two lines** of the same material, 6 kg each → must 422 on the combined 12. A per-line check passes both; this is the step-03 bug and you must not reproduce it here.

**4. Regression.** Spend **exactly** the balance → 201, balance lands on exactly 0. This is where float comparison would have failed and `bccomp` should not. Then `received` of any size → 201, never blocked.

**5. The decimal migration.** Run the pre-flight queries above, then the ALTER, then:

```sql
SHOW COLUMNS FROM raw_material_stock_movements LIKE 'quantity';   -- decimal(12,3)
```

Compare per-material balances against a snapshot taken before the ALTER. Small movements are the float noise you are removing — expected. Large ones are a problem; investigate rather than accepting.

**6. Precision, end to end.** Post ten `received` movements of `0.1` for a fresh material. Balance must be **exactly 1.000**:

```sql
SELECT SUM(quantity) FROM raw_material_stock_movements WHERE material_id = <new>;
-- must be exactly 1.000, not 0.9999999999999999
```

That is the whole point of the type change. Then `GET` the movements and check the API returns `"0.100"` — and **check the client app renders it**, per the warning above.

**7. `destroy`.**
- Material **with** movements → **409** and a readable message. Not 500. `SELECT * FROM raw_materials WHERE id = <id>` still returns the row.
- Material **without** movements → 200, row gone.

**8. Drive the real UI.** Raw material screens on staging: create a material, receive stock, spend stock, try to over-spend, try to delete. All five by hand. The over-spend must fail with a message a warehouse clerk can act on.

## Rollback

Three independent pieces — deploy them separately so they roll back separately.

| Piece | Rollback |
|---|---|
| Stock validation | `RAW_MATERIALS_ENFORCE_STOCK_VALIDATION=false` + `php artisan config:clear`. Instant, no deploy. |
| `destroy` 409 | `git revert`. Returns to throwing 500s. Harmless. |
| decimal migration | `down()` reverts to `DOUBLE` — but **the 3dp rounding is not undone**. Values rounded on the way in stay rounded. Effectively one-way. |

The decimal change is the one that needs care. Take a dump of `(id, quantity)` before the ALTER:

```sql
SELECT id, quantity FROM raw_material_stock_movements ORDER BY id;
```

Reverting the *model* cast without reverting the *column* is fine — `float` cast on a `decimal` column works. Reverting the column without the cast is also fine. They are independent, which is useful.

**Deploy order:** `destroy` fix first (trivial, no risk), then the decimal migration (needs a window if the table is large), then the validation behind its flag. Do not bundle them.

## Depends on / blocks

- **Depends on:** nothing. This subsystem is self-contained — raw materials share no tables with variants, shipments, or stock movements.
- **Blocks:** nothing.
- **Parallel-safe.** Touches no file any other phase-1 step touches. Good work to hand to a second developer while 01-05 proceed.
- **Pattern debt:** this is now the **third** copy of "sum movements, compare, reject" (`ShipmentService:404-438`, `WarehouseDocumentService:209-257`, and here). Do not try to unify them in this step — the raw material table has a different shape and a different type. Note it for phase-2, where the balance-row work should address all three at once.
