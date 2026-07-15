# 08 — `php artisan stock:reconcile`

Assert `SUM(stock_movements) == product_variant_stock.quantity` per variant, nightly. Same shape as step 06, for stock.

**Severity:** High — step 07's balance is unverified without it / **Effort:** 1 day / **Safe on live:** Yes read-only; `--fix` writes and needs care

## Why this matters

Step 07 replaced a live `SUM` with a cached balance. The live SUM was slow and unlockable, but it had one property the balance does not: **it could not be wrong.** It was recomputed from the ledger on every read.

The balance can be wrong. It is a cache, and a cache that is never checked is just a second number that happens to be nearby. It drifts when:

- a writer of `stock_movements` was missed in step 07's grep (the most likely failure, and the most dangerous — silent from day one)
- a new feature inserts a movement and copies the pre-07 pattern, six months from now
- someone runs `UPDATE product_variant_stock SET quantity = 50` by hand to "fix" a variant
- a transaction partially applies, or a movement is inserted outside one
- the backfill raced a live write (step 07's §4 warning)

The consequence is worse than the bug step 07 fixed. Before 07, a negative balance meant carpets were shipped that did not exist. After 07, a drifted balance means **`assertSufficientStock()` is making decisions on a wrong number** — it is the lock target *and* the gate. A balance reading 50 when the ledger says 5 lets the warehouse ship 50 carpets, confidently, with no error, from a variant that has 5. The ledger will say −45 and the balance will say 0, and nobody will know which to believe or when it started.

Concrete: a movement writer is missed. Every OUT through that path decrements the ledger and not the balance. Over a month the balance drifts +200 on a fast-moving variant. The stock page shows 200 carpets that do not exist, sales are promised against them, and the discovery is a client's order that cannot be filled. With this command it is an alert on the first night.

**The ledger is always the truth.** `stock_movements` is append-only and correct. When the two disagree, the balance is wrong — this command never questions the ledger, and neither should you.

## Files to change

| File | Status | Notes |
|---|---|---|
| `tgc_backend/app/Console/Commands/StockReconcile.php` | new | the command |
| `tgc_backend/routes/console.php` | 1–9 | add the schedule alongside step 06's |

Laravel `^13.0` — commands auto-register from `app/Console/Commands/`; scheduling lives in `routes/console.php`.

## The change

### 1. The query

```sql
SELECT
    v.id                                AS product_variant_id,
    COALESCE(s.quantity, 0)             AS balance,
    COALESCE(m.qty, 0)                  AS ledger,
    COALESCE(s.quantity, 0) - COALESCE(m.qty, 0) AS drift
FROM product_variants v
LEFT JOIN product_variant_stock s ON s.product_variant_id = v.id
LEFT JOIN (
    SELECT product_variant_id,
           SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END) AS qty
    FROM stock_movements
    GROUP BY product_variant_id
) m ON m.product_variant_id = v.id
WHERE COALESCE(s.quantity, 0) <> COALESCE(m.qty, 0)
ORDER BY ABS(COALESCE(s.quantity, 0) - COALESCE(m.qty, 0)) DESC;
```

Driving from `product_variants` with `LEFT JOIN`s on both sides is deliberate — it catches the two cases a narrower query would miss:

- a variant with **movements but no balance row** (dual-write never created it) → balance 0, ledger 12, drift −12
- a variant with **a balance row but no movements** (phantom balance) → balance 12, ledger 0, drift +12

Joining `product_variant_stock` to the movements subquery directly would hide both. The `movement_type` `CASE` mirrors `StockMovement::TYPE_IN` / `TYPE_OUT`; use the constants in PHP rather than hardcoding the strings.

Drift sign is diagnostic:

- **positive** (`balance > ledger`) — the balance was credited without a movement, or an OUT movement skipped the dual-write. **This is the dangerous direction**: the system thinks it has stock it does not, and will happily ship it.
- **negative** (`balance < ledger`) — an IN movement skipped the dual-write. Stock exists that the system will not sell. Costly, not corrupting.

### 2. The command

Mirror step 06's structure exactly — same options, same report order, same exit-code contract. Two commands that do the same job should look the same.

```php
class StockReconcile extends Command
{
    protected $signature = 'stock:reconcile
                            {--fix        : write an adjustment movement to close the drift}
                            {--variant=   : check a single product_variant id}
                            {--limit=50   : max rows to print}';

    protected $description = 'Assert product_variant_stock.quantity == SUM(stock_movements).';

    public function handle(): int
    {
        $drifted = $this->findDrift($this->option('variant'));

        if ($drifted->isEmpty()) {
            $this->info('stock:reconcile — OK, ' . $this->variantCount() . ' variants, no drift.');
            return self::SUCCESS;
        }

        $this->error("stock:reconcile — DRIFT on {$drifted->count()} variant(s).");

        $this->table(
            ['variant', 'product', 'balance', 'ledger', 'drift'],
            $drifted->take((int) $this->option('limit'))->map(fn ($r) => [
                $r->product_variant_id, $r->product_name ?? '—',
                $r->balance, $r->ledger, $r->drift,
            ]),
        );

        $this->warn('Net drift: ' . $drifted->sum('drift')
                  . ' | over-stated: '  . $drifted->where('drift', '>', 0)->sum('drift')
                  . ' | under-stated: ' . $drifted->where('drift', '<', 0)->sum('drift'));

        return self::FAILURE;
    }
}
```

**Report, in this order:**

1. **count of drifted variants** — 1 is a bug, 500 is a missed writer
2. **net drift, split by direction** — do not net them off; +200/−200 nets to 0 and is two serious bugs, not health
3. **worst offenders** — capped by `--limit`; join `products.name` so the report names a carpet, not an integer
4. **exit code** — `FAILURE` on any drift; this is the alerting mechanism

Add a **negative-stock check** while you are here — different from drift, and worth its own line. A variant where ledger and balance *agree* on a negative value is not drift, it is the step-07 race having already fired:

```php
$negative = DB::table('product_variant_stock')->where('quantity', '<', 0)->get();
if ($negative->isNotEmpty()) {
    $this->error("{$negative->count()} variant(s) have NEGATIVE stock — carpets shipped that never existed.");
}
```

`StockController::variants()` line 154 (`HAVING quantity_warehouse > 0`) hides these from the UI entirely. This command is the only place they will ever surface.

### 3. `--fix`

Same principle as step 06, with one important difference: **stock has no `correction` event type.** `StockMovement::TYPES` is `['in', 'out']` only (verified in `app/Models/StockMovement.php`).

So `--fix` **corrects the balance to match the ledger** — the opposite direction from step 06's `--fix`, and deliberately so:

```php
private function applyFix($drifted): void
{
    foreach ($drifted as $row) {
        DB::table('product_variant_stock')->upsert(
            [['product_variant_id' => $row->product_variant_id, 'quantity' => $row->ledger,
              'created_at' => now(), 'updated_at' => now()]],
            ['product_variant_id'],
            ['quantity', 'updated_at'],
        );
    }
}
```

Why the opposite of step 06:

- In production, the **cache is what the floor sees and acts on**, and the log may be incomplete — so `--fix` trusts the cache and writes a correction event.
- In stock, the **ledger is complete and authoritative by construction** — every movement is a real document line. The balance is a derived convenience. So `--fix` recomputes the balance from the ledger. There is nothing to append; the ledger already says the truth.

This means `stock:reconcile --fix` is exactly `stock:backfill-balances` scoped to drifted variants. That is fine, and it is a good sign — it means both derive the same number from the same source.

**Do not put `--fix` in the schedule.** Drift means a writer is broken. Silently correcting it nightly means the bug lives forever and you have built a machine for hiding it. A human runs `--fix` after finding the cause. Write that in the runbook.

`--fix` does **not** resolve negative stock. A negative balance that matches the ledger is a physical discrepancy — carpets were shipped that did not exist. Only the floor can resolve it, with a real `adjustment` warehouse document that leaves an auditable movement. Never `UPDATE` a negative away.

### 4. Schedule it

```php
use Illuminate\Support\Facades\Schedule;

Schedule::command('stock:reconcile')
    ->dailyAt('02:45')
    ->onFailure(function (): void {
        // Alert a human.
    });
```

02:45 — after step 06's 02:30, so the two do not contend, and both land before anyone opens a report.

**Wire the alert to something a human reads.** Same point as step 06 and it bears repeating: a non-zero exit code that goes nowhere is not a signal. Confirm cron is actually invoking `schedule:run` on the box (`crontab -l` for the deploy user) — otherwise this command is decoration.

## How to verify

No test suite. Manual.

1. **Clean baseline.** After step 07's backfill:
   ```bash
   php artisan stock:reconcile; echo "exit=$?"
   ```
   Must print OK and `exit=0`. If it reports drift here, step 07's backfill or dual-write is wrong — fix that; this command is the messenger.
2. **Inject drift, confirm detection.** On staging:
   ```sql
   UPDATE product_variant_stock SET quantity = quantity + 13 WHERE product_variant_id = <VARIANT>;
   ```
   ```bash
   php artisan stock:reconcile --variant=<VARIANT>; echo "exit=$?"
   ```
   Must report `drift = 13` and `exit=1`. **A reconcile command that has never caught a planted bug is not known to work.**
3. **Missing balance row.** The case a narrower query would miss:
   ```sql
   DELETE FROM product_variant_stock WHERE product_variant_id = <VARIANT>;
   ```
   Must report `balance = 0`, `ledger = <real>`, negative drift — **not** silently skip the variant. If it reports OK, the query is not driving from `product_variants`.
4. **Phantom balance.** A balance row for a variant with zero movements must report positive drift equal to the balance.
5. **Simulate a missed writer** — the failure this command exists to catch:
   ```sql
   INSERT INTO stock_movements (uuid, product_variant_id, user_id, movement_type, quantity, movement_date, created_at, updated_at)
   VALUES (UUID(), <VARIANT>, 1, 'out', 4, NOW(), NOW(), NOW());
   ```
   (a movement with no balance update, exactly as a missed dual-write would produce). Reconcile must report `drift = +4`.
6. **`--fix` closes it, from the ledger.**
   ```bash
   php artisan stock:reconcile --variant=<VARIANT> --fix
   php artisan stock:reconcile --variant=<VARIANT>; echo "exit=$?"
   ```
   Second run OK, exit 0. Confirm the **ledger was not touched** — this is the one thing `--fix` must never do:
   ```sql
   SELECT COUNT(*) FROM stock_movements WHERE product_variant_id = <VARIANT>;   -- unchanged
   SELECT quantity FROM product_variant_stock WHERE product_variant_id = <VARIANT>;  -- == ledger
   ```
7. **Negative stock surfaces.** Force one (`UPDATE ... SET quantity = -3` plus a matching OUT movement so they agree) and confirm the command reports it as negative stock, **not** as drift. Two different problems, two different lines in the report.
8. **Performance.** The subquery aggregates all of `stock_movements`:
   ```sql
   SELECT COUNT(*) FROM stock_movements;
   ```
   Time it against production-sized data. At factory scale a full scan at 02:45 is fine — do not optimise before measuring. If it does become slow, `stock_movements(product_variant_id, movement_type)` is the index to consider.
9. **The alert actually fires.** Leave planted drift, then `php artisan schedule:test --name="stock:reconcile"`. **Confirm a human receives something.** If not, this step is not done.
10. **Run it daily for a week before switching reads** (step 07 §6). A week of clean reconciles is the evidence that no writer was missed. That is the gate — not a code review, a week of green.

## Rollback

The safest step in the phase, alongside 06.

- **Read-only by default.** Remove the `Schedule::command(...)` line to stop it; delete the file to remove it. Neither touches data.
- **`--fix` overwrites `product_variant_stock.quantity`** — it never touches `stock_movements`, so there is nothing to undo in the ledger. If a `--fix` run was wrong, re-run `stock:backfill-balances` and the balance is recomputed from the ledger. The ledger is the backup, permanently and by construction.
- **Never roll back by editing `stock_movements`.** If the balance disagrees with the ledger, the balance is wrong. Always. The ledger is the only record of what physically moved.
- If reconcile is noisy and you cannot fix the cause immediately, **narrow it rather than disabling it** — scope with `--variant`, keep the alert alive for everything else. A disabled alarm is how you end up back where this phase started.

## Depends on / blocks

- **Depends on: 07** — the `product_variant_stock` table must exist to assert against. Build it the moment 07's dual-write lands, before the backfill, so you can verify the backfill *with* it (step 07's verification #2 is this command's query — formalise it here and reuse it there).
- **Independent of 01–06.** 07 + 08 are a parallel workstream; a second developer can take them start to finish.
- **Blocks: 07's read switch (§6) in practice.** Do not point `getStock()` and `StockController` at the balance until this command has run clean for a week. That week of green is the only evidence you will get that no writer was missed.
- Build **after 06** if the same person is doing both — copy that command's structure rather than inventing a second one.
