# 06 — Soft-delete payments, and stop hiding debt behind deleted clients

`DELETE /payments/{id}` hard-deletes the row. The money is gone with no trail. Separately, soft-deleting a client hides their debt from the debit report while the receivable remains real.

**Severity: High / Effort: 4h / Safe on live: Yes.**

## Why this matters

### Payments vanish

`app/Models/Payment.php` has no `SoftDeletes` trait — the class uses only `HasFactory` (line 11). And `app/Http/Controllers/Api/V1/PaymentController.php:47-52`:

```php
public function destroy(Payment $payment): JsonResponse
{
    $payment->delete();

    return response()->json(null, 204);
}
```

That is a hard `DELETE FROM payments WHERE id = ?`. One API call and a $4,000 payment ceases to have ever existed. There is no `deleted_at`, no audit table, no event log. The client's balance jumps by $4,000 and **nothing in the database explains why**. The office cannot tell a mistaken deletion from a legitimate correction from a fraudulent one, because all three look identical: an absence.

Nothing else in the schema references `payments`, so there is no FK to block the delete and no orphan to notice afterwards. It is a clean, silent, total loss of a financial record.

Compare `Client` and `Product`, the only two models that use `SoftDeletes` (verified: `grep -rln 'SoftDeletes' app/Models/` returns exactly those two). Clients — reference data — are protected. Payments — money — are not.

### Deleted clients hide live debt

`app/Services/ClientDebitService.php:51` builds the debit report on `Client::query()`:

```php
return Client::query()
    ->leftJoinSub($debitSub, 'dbt', fn ($j) => $j->on('clients.id', '=', 'dbt.client_id'))
    ->leftJoinSub($creditSub, 'crd', fn ($j) => $j->on('clients.id', '=', 'crd.client_id'))
```

`Client` uses `SoftDeletes` (`app/Models/Client.php:13`), so `Client::query()` silently appends `WHERE clients.deleted_at IS NULL`. Soft-delete a client and they **disappear from the debit report entirely** — while their shipments, their `shipment_items`, and the receivable those represent all remain untouched in the database.

Concretely: client 42 owes $12,000. Someone soft-deletes the client record — tidying up, or a mistake, or worse. The debit list no longer shows client 42. The $12,000 is still owed, the carpets have still left the factory, but the report that exists to tell you who owes money has quietly stopped mentioning them. **The receivable does not go away; only the visibility does.**

Note the schema actively prevents the honest version of this: `payments.client_id` is `restrictOnDelete` (`create_payments_table:14`), so a hard delete of a client with payments is blocked by the FK. Soft-delete is the *only* way to remove a client — which means this path is not an edge case, it is the only path.

`getLedger` is unaffected: it takes a `Client` already resolved by route-model binding, and reads `Shipment::where('client_id', ...)` directly (line 92). So a soft-deleted client's ledger still works **if you know the URL** — the summary list is where they vanish.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | What |
|---|---|---|
| `app/Models/Payment.php` | 9-11 | Add `SoftDeletes`. |
| `database/migrations/` | new | Add `deleted_at` to `payments`. |
| `app/Http/Controllers/Api/V1/PaymentController.php` | 47-52 | `destroy` — and read the void discussion below. |
| `app/Http/Controllers/Api/V1/PaymentController.php` | 17-23 | `index` — confirm the scope excludes trashed. |
| `app/Services/ClientDebitService.php` | 51 | `withTrashed()`. |
| `app/Services/ClientDebitService.php` | 47-49 | The credit subquery — see the trap below. |

## The change

### 1. Migration

```php
Schema::table('payments', function (Blueprint $table) {
    $table->softDeletes();          // deleted_at TIMESTAMP NULL, after the last column
    $table->index('deleted_at');    // index it: every query now filters on it
});
```

Additive and nullable. Safe to run live — existing rows get `NULL`, meaning "not deleted", which is correct for every one of them.

### 2. The model

```php
use Illuminate\Database\Eloquent\SoftDeletes;

class Payment extends Model
{
    use HasFactory, SoftDeletes;
```

That is the whole change. `$payment->delete()` in the controller now sets `deleted_at` instead of removing the row, and `Payment::query()` excludes trashed rows by default — **including the `getLedger` read at `ClientDebitService.php:129`**, which is what you want: a deleted payment should stop crediting the client.

### 3. The trap: the credit subquery does not know about the trait

`ClientDebitService::getSummaries` lines 47-49:

```php
$creditSub = DB::table('payments')
    ->select('client_id', DB::raw('SUM(amount) AS total_credit'))
    ->groupBy('client_id');
```

That is `DB::table()`, not `Payment::query()`. **The `SoftDeletes` global scope does not apply.** The moment you add the trait, this subquery starts counting deleted payments while `getLedger` (line 129, `Payment::where(...)`) stops counting them. The two reports diverge immediately, and the divergence is exactly the amount of every deleted payment.

This is the sharpest edge in the step and it is invisible unless you look for it:

```php
// intended — lines 47-49
$creditSub = DB::table('payments')
    ->whereNull('deleted_at')       // SoftDeletes scope does NOT reach DB::table()
    ->select('client_id', DB::raw('SUM(amount) AS total_credit'))
    ->groupBy('client_id');
```

Grep for any other raw reader of the table before you ship:

```bash
grep -rn "DB::table('payments')\|from payments\|JOIN payments" app/ database/
```

Each hit needs the same treatment. A raw query that silently ignores a new global scope is how a soft-delete rollout produces wrong money.

### 4. `withTrashed()` for clients in the debit report

```php
// current — line 51
return Client::query()

// intended
// Soft-deleted clients can still owe money: their shipments and the
// receivable are untouched by deleting the client record. A debt report
// that hides them is worse than useless.
return Client::withTrashed()
```

Now a soft-deleted client with an outstanding balance appears in the report. Two consequences to handle rather than discover:

- **The response must say they are deleted.** `->select(['clients.*', ...])` (lines 54-59) already carries `deleted_at` through, so the API can expose it. Check `ClientResource` (or whatever the debit controller returns) surfaces it, and have the client app show a "deleted" marker. Otherwise the office sees a client they thought was gone, with no explanation, and files a bug.
- **`has_balance` filtering still works** — `havingRaw('balance > 0')` (line 74) is unaffected. A deleted client with a zero balance stays invisible in practice, which is the sensible default. Consider whether the *unfiltered* list should include zero-balance deleted clients at all; `withTrashed()` alone will show them. If that is noise, scope it:

```php
return Client::withTrashed()
    // ... joins ...
    ->when(
        ! $includeDeleted,
        fn ($q) => $q->where(fn ($q2) => $q2->whereNull('clients.deleted_at')
                                            ->orWhereRaw('COALESCE(dbt.total_debit, 0) - COALESCE(crd.total_credit, 0) > 0'))
    )
```

That reads: show live clients always, deleted clients only if they still owe. Decide with the office which they want; do not pick silently.

### 5. `destroy` — and why soft-delete is not actually the fix

Add the trait and `destroy` becomes reversible. That is a real improvement over the status quo and it is what this step ships.

But be clear about what it is: **a soft-deleted payment is still a payment that disappeared from every report with no stated reason.** `deleted_at` records *that* someone deleted it and *when*. It does not record *who* or *why*. The office still cannot distinguish a typo correction from a dispute from a mistake.

For money, the correct model is a **void/reversal**, not a delete:

- The original payment row is never modified. It stays visible in the ledger, marked void.
- A reversing entry, or a `voided_at` / `voided_by` / `void_reason` triple, records who voided it and why.
- The ledger shows both: "payment $4,000", "voided by Aziz on 14 July — duplicate entry". The balance is correct **and** the history explains itself.

That is what an accountant expects and what an auditor requires. It is also more than 4 hours of work, because it needs a UI to capture the reason and a ledger that renders voids.

**Recommendation:** ship soft-deletes now — it stops the unrecoverable loss today, cheaply, and it is a strict improvement. Then open a follow-up for the void concept and make the case for it properly. Do not let "soft-delete is not ideal" block the fix that stops money vanishing this week.

If you have the appetite now, the minimum honest version is three columns and a required reason:

```php
$table->timestamp('voided_at')->nullable();
$table->foreignId('voided_by')->nullable()->constrained('users');
$table->string('void_reason');   // NOT nullable — if you cannot say why, you cannot void
```

...with `destroy` replaced by `POST /payments/{id}/void` taking a mandatory reason, and the ledger rendering voided payments as visible zero-credit entries. That is the right destination. Soft-delete is the step towards it, not a substitute.

### 6. Check `index` and any restore path

`PaymentController::index` (lines 17-23) uses `Payment::with(...)`, which picks up the global scope and excludes trashed. Correct by default.

There is currently **no restore endpoint**. Soft-delete without restore means the data is recoverable only via tinker — better than gone, but not a feature. Either add `POST /payments/{id}/restore`, or accept that recovery is a developer task and say so. Do not imply a restore exists in the UI if it does not.

## How to verify

No test suite. Staging, restored from a production dump.

**1. Baseline.** Pick a client with payments:

```sql
SELECT id, client_id, amount, created_at FROM payments WHERE client_id = <c> ORDER BY id;
SELECT COUNT(*), SUM(amount) FROM payments WHERE client_id = <c>;
```

Record the debit report and ledger figures:
- `GET /api/v1/clients/debits?search=<shop_name>` → `total_credit`, `balance`
- `GET /api/v1/clients/{c}/debit-ledger` → `summary.total_credit`

**2. Delete a payment.**

```bash
curl -X DELETE https://staging/api/v1/payments/<id> -H "Authorization: Bearer $TOKEN"
```

- **Before the change:** 204, and `SELECT * FROM payments WHERE id = <id>` returns **nothing**. Row gone.
- **After the change:** 204, and the row is **still there** with `deleted_at` set:

```sql
SELECT id, amount, deleted_at FROM payments WHERE id = <id>;   -- deleted_at IS NOT NULL
```

**3. The divergence check — this is the one that catches the `DB::table` trap.** After deleting, both reports must agree:

- `GET /api/v1/clients/debits?search=<shop_name>` → `total_credit`
- `GET /api/v1/clients/{c}/debit-ledger` → `summary.total_credit`

**These must be equal, and both must have dropped by the deleted amount.** If the ledger dropped and the debit list did not, you missed the `whereNull('deleted_at')` at line 47. This is the failure the step is most likely to ship with — check it explicitly, do not assume.

The deleted payment must also be gone from the ledger entries array, not merely from the summary.

**4. Restore and re-check.**

```php
// tinker
\App\Models\Payment::withTrashed()->find(<id>)->restore();
```

Both figures must return to the baseline exactly. This proves the delete was genuinely reversible — the entire point of the change.

**5. The deleted-client case.** Find or create a client with an outstanding balance, then soft-delete them:

```sql
SELECT c.id, c.shop_name, c.deleted_at FROM clients c WHERE c.id = <c>;
```

```php
// tinker
\App\Models\Client::find(<c>)->delete();
```

- **Before the change:** `GET /api/v1/clients/debits` — the client is **absent**. Their debt is invisible.
- **After the change:** the client **appears**, with the same `balance` as before deletion, and the response marks them deleted.

Confirm the debt was real all along:

```sql
-- The receivable, untouched by the client's deletion
SELECT SUM(CASE WHEN p.unit = 'm2' AND ps.id IS NOT NULL
                THEN si.price * ps.length * ps.width * si.quantity / 10000
                ELSE si.quantity * si.price END) AS owed
FROM shipment_items si
JOIN shipments s         ON s.id  = si.shipment_id
JOIN product_variants pv ON pv.id = si.product_variant_id
JOIN product_colors pc   ON pc.id = pv.product_color_id
JOIN products p          ON p.id  = pc.product_id
LEFT JOIN product_sizes ps ON ps.id = pv.product_size_id
WHERE s.client_id = <c>;
```

That number exists whether or not the client row has a `deleted_at`. That is the whole argument for `withTrashed()`.

**6. Run the production query before deploying**, so you know what the office is about to see:

```sql
SELECT c.id, c.shop_name, c.deleted_at
FROM clients c
WHERE c.deleted_at IS NOT NULL
  AND EXISTS (SELECT 1 FROM shipments s WHERE s.client_id = c.id);
```

Every row is a soft-deleted client with shipment history who will reappear in the debit report on deploy. **If that list is non-empty, tell the office before shipping** — clients they deleted months ago are about to show up owing money. That is correct, and it will still look like a bug if it arrives unannounced.

**7. Pagination sanity.** `withTrashed()` widens the result set. Check `GET /api/v1/clients/debits` page counts and the `has_balance=1` filter still behave.

## Rollback

- **Code:** `git revert`. The trait comes off, `destroy` hard-deletes again, the debit report re-hides deleted clients.
- **Migration:** `deleted_at` can stay. It is nullable and additive; an unused column costs nothing. **Prefer leaving it.** Dropping it destroys the record of every soft-delete made while the fix was live — the exact data the step exists to preserve.

If you must drop it: `Schema::table('payments', fn ($t) => $t->dropSoftDeletes());`. Export the soft-deleted rows first:

```sql
SELECT * FROM payments WHERE deleted_at IS NOT NULL;
```

Reverting the code without dropping the column leaves soft-deleted payments invisible to `Payment::query()` (no trait, no scope, so they are counted again) — meaning a reverted deploy **re-credits** every soft-deleted payment. Check that before reverting: if any payment was soft-deleted while the fix was live, a plain revert changes client balances. Hard-delete those rows as part of the revert, or do not revert.

## Depends on / blocks

- **Depends on:** nothing. This is the smallest, safest step in phase 1 — a good one to build confidence on.
- **Blocks:** nothing.
- **Conflicts with step 01.** Both edit `ClientDebitService::getSummaries`: step 01 rewrites the `$debitSub` raw expression (lines 33-42), this step touches `$creditSub` (lines 47-49) and the `Client::query()` at line 51. Different lines, adjacent code. **Sequence them rather than parallelising** — do 01 first, since it establishes what the numbers should be, then 06.
- **Follow-up:** the void/reversal concept in section 5. Open the ticket when you ship this, while the reasoning is fresh.
