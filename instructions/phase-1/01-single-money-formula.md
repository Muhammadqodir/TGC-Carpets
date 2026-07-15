# 01 — One money formula, one rounding rule

The shipment line total is computed in four places with three different rounding rules, so the invoice, the ledger and the debit report disagree about what a client owes.

**Severity: High / Effort: 2d / Safe on live: Yes, but totals will move by cents — tell users first.**

## Why this matters

The formula is: for `m2` products, `price × length × width × quantity / 10000`; otherwise `price × quantity`. Every caller agrees on the formula and disagrees on when to round.

Worked example, verified against the code below. A shipment with **two lines**, each one carpet of 55 × 105 cm at price 10.00:

- Per line: `55 × 105 / 10000 = 0.5775 m²`, `× 10.00 = 5.775`
- **Invoice PDF and API resource** round per line: `round(5.775, 2) = 5.78` each → total **11.56**
- **Ledger** accumulates raw and rounds once per shipment: `5.775 + 5.775 = 11.55` → **11.55**
- **Debit report** (`getSummaries`) does not round at all → returns something like `11.55` here, but for other inputs emits full precision such as `1.344915` straight into the JSON response.

So the same shipment is 11.56 on the invoice the client is handed, 11.55 in the ledger the office reads, and an unrounded float in the client debit list. Nobody can reconcile the three, and the discrepancy compounds across every line of every shipment.

There is a fourth divergence hiding in the PDF: it rounds `$sqm` to 4 decimal places *before* multiplying by price, which the API resource does not do.

## Files to change

All paths relative to `/Users/mqodir/Documents/GitHub/TGC-Carpets/tgc_backend`.

| File | Lines | Current behaviour |
|---|---|---|
| `app/Http/Resources/ShipmentItemResource.php` | 40 (call), 48-63 (`computeTotal`) | Rounds per line. PHP float. |
| `app/Services/ClientDebitService.php` | 100-112 (accumulate), 119 (`round($total, 2)`) | Rounds per shipment. PHP float. |
| `app/Services/ClientDebitService.php` | 33-42 (`SUM(...)` raw SQL in `getSummaries`) | No rounding. MySQL DECIMAL. |
| `resources/views/pdf/shipment_hisob_faktura.blade.php` | 224-234 | Rounds `$sqm` to 4dp, then rounds the line to 2dp. |
| `app/Models/ShipmentItem.php` | — | Add the new method here. |

Note the PDF path is `resources/views/pdf/shipment_hisob_faktura.blade.php`. The audit note said `resources/views/.../shipment_hisob_faktura.blade.php`; `pdf/` is the actual directory. Rendered from `ShipmentService::generateAndStoreHisobFaktura` (`app/Services/ShipmentService.php:237`).

## The change

### 1. Add `lineTotal()` to `ShipmentItem`

`price` is already cast `decimal:2` (`app/Models/ShipmentItem.php:26`), which means Eloquent hands you a **string**. That is what you want — feed it straight to bcmath and never let it become a float.

`bcmath` is enabled on this machine (verified: `bcadd` exists). `brick/math` is present in `vendor/` but only as a transitive dependency — it is **not** in the `require` block of `composer.json`. If you prefer `brick/math`, add it explicitly to `composer.json` first; do not rely on a transitive dependency. Otherwise use bcmath, which needs no new dependency.

```php
// app/Models/ShipmentItem.php

/**
 * The authoritative money value for this line, rounded to 2dp.
 *
 * m2 products:  price × length × width × quantity / 10000
 * otherwise:    price × quantity
 *
 * Requires: variant.productColor.product and variant.productSize to be loaded
 * (or they will lazy-load — acceptable, but eager-load in loops).
 */
public function lineTotal(): string
{
    $price = (string) $this->getRawOriginal('price');
    $qty   = (string) $this->quantity;
    $unit  = $this->variant?->productColor?->product?->unit ?? 'piece';
    $size  = $this->variant?->productSize;

    if ($unit === 'm2' && $size) {
        // price × length × width × qty / 10000, full precision until the end.
        $area  = bcmul((string) $size->length, (string) $size->width, 6);
        $area  = bcmul($area, $qty, 6);
        $gross = bcmul($price, $area, 8);
        $raw   = bcdiv($gross, '10000', 8);
    } else {
        $raw = bcmul($price, $qty, 8);
    }

    return $this->round2($raw);
}

/** bcmath truncates; this rounds half-up, which is what round() did. */
private function round2(string $value): string
{
    $add = str_starts_with($value, '-') ? '-0.005' : '0.005';

    return bcadd($value, $add, 2);
}
```

Two things to be deliberate about:

- **`getRawOriginal('price')`** bypasses the `decimal:2` cast accessor. The cast returns a string already, so `(string) $this->price` also works; using the raw value makes the intent explicit and is immune to a future cast change.
- **bcmath truncates, `round()` rounds half-up.** Without `round2`, `5.775` becomes `5.77` and every existing figure shifts down. The `round2` helper reproduces the current half-up behaviour. Do not skip it.

### 2. `ShipmentItemResource`

Delete the private `computeTotal()` (lines 48-63) and change line 40:

```php
// current
'total'        => $this->computeTotal(),

// intended
'total'        => $this->resource->lineTotal(),
```

Use `$this->resource->` rather than `$this->`. `JsonResource::__call` forwards unknown methods to the underlying model, so `$this->lineTotal()` would also work, but being explicit avoids surprises if a resource method of the same name is ever added.

### 3. `ClientDebitService::getLedger`

Replace the accumulation loop (lines 100-112) and the round at line 119:

```php
// current (lines 98-119, abridged)
foreach ($shipments as $shipment) {
    $total = 0.0;
    foreach ($shipment->items as $item) {
        $unit = $item->variant?->productColor?->product?->unit ?? 'piece';
        if ($unit === 'm2') {
            $size = $item->variant?->productSize;
            if ($size) {
                $total += (float) $item->price * $size->length * $size->width * $item->quantity / 10000.0;
            } else {
                $total += (float) $item->quantity * (float) $item->price;
            }
        } else {
            $total += (float) $item->quantity * (float) $item->price;
        }
    }
    // ...
    'debit' => round($total, 2),

// intended
foreach ($shipments as $shipment) {
    $total = '0.00';
    foreach ($shipment->items as $item) {
        $total = bcadd($total, $item->lineTotal(), 2);
    }
    // ...
    'debit' => $total,
```

Rounding now happens per line inside `lineTotal()`, and the shipment total is the sum of already-rounded lines. That matches the invoice. This is the behaviour to standardise on: **the client is billed the sum of the printed line totals**, because that is the document they hold.

The eager-load at lines 87-91 already pulls `items.variant.productColor.product` and `items.variant.productSize`, so `lineTotal()` will not trigger N+1 here. Leave it in place.

The running balance (lines 150-155) and summary (lines 158-165) still use float arithmetic. Convert them to bcmath too, or accept that they are sums of clean 2dp values and the float error stays far below a cent for realistic ledger sizes. Converting is cheap; prefer it.

### 4. `ClientDebitService::getSummaries` — the awkward one

This is a SQL aggregate joined into a paginated `Client::query()` (line 51). You cannot call `lineTotal()` per row without destroying pagination and issuing a query per client.

**Round inside the SQL, per line, before the SUM** — this reproduces `lineTotal()` exactly for the m² path:

```sql
-- current (lines 33-42): no rounding anywhere
SUM(
    CASE
        WHEN p.unit = 'm2' AND ps.id IS NOT NULL
            THEN si.price * ps.length * ps.width * si.quantity / 10000.0
        ELSE
            si.quantity * si.price
    END
) AS total_debit

-- intended: round each line, then sum
SUM(
    ROUND(
        CASE
            WHEN p.unit = 'm2' AND ps.id IS NOT NULL
                THEN si.price * ps.length * ps.width * si.quantity / 10000.0
            ELSE
                si.quantity * si.price
        END,
        2
    )
) AS total_debit
```

Caveats you must check rather than assume:

- **`/ 10000.0` forces MySQL into DOUBLE arithmetic.** Change it to `/ 10000` so the DECIMAL type of `si.price` propagates and the division stays exact. Verify with the query in "How to verify".
- **MySQL `ROUND()` on DECIMAL rounds half-away-from-zero**, matching `round2`. On DOUBLE it rounds to nearest even in some builds. Removing the `.0` is what keeps these two agreeing — do not skip it.
- This duplicates the formula in SQL. That is a real and knowing compromise: two expressions of one rule. Put a comment above both pointing at each other, and note that phase-2's balance table is what removes the duplication for good.

If you cannot make the SQL agree with `lineTotal()` to the cent in the verification step below, **do not ship a near-miss**. Fall back to computing the debit in PHP over the current page of clients (`$paginator->getCollection()`), accepting the extra queries, and open a follow-up. A report that is honestly slow beats one that is quietly wrong.

### 5. The PDF template

```blade
{{-- current (lines 224-234) --}}
$sqm = ($size && $unit === 'm2')
    ? round(($size->length * $size->width * $qty) / 10000, 4)
    : 0;

$lineTotal = ($unit === 'm2' && $sqm > 0)
    ? round($price * $sqm, 2)
    : round($price * $qty, 2);

{{-- intended --}}
$sqm = ($size && $unit === 'm2')
    ? round(($size->length * $size->width * $qty) / 10000, 4)
    : 0;                       {{-- display only, never used for money --}}

$lineTotal = (float) $item->lineTotal();
```

Keep `$sqm` for the m² display columns; it must no longer touch the money column. `$grandTotalPrice` (line 234) then accumulates already-rounded line totals, which is what the ledger now does too.

### Separate bug, same block — report before fixing

Line 225 computes `$sqm` as `length × width × qty / 10000` — **quantity is already in it**. Line 258 then prints:

```blade
<td class="right">{{ number_format($sqm * $qty, 2) }} m²</td>   {{-- "Jami m²" column --}}
```

That multiplies by quantity a second time. For qty=1 nobody noticed. For a line of 5 carpets the "Jami m²" column reads 5× the truth. The "m²" column at line 250 prints `$sqm` unmodified, so it shows the *total* area under a header meaning *unit* area.

This is a display bug, not a money bug — `$lineTotal` never reads either column, so invoice totals are unaffected. It is out of scope here. **Raise it with whoever reads these PDFs before changing it**: if staff have been treating the "Jami m²" figure as authoritative for anything, correcting it silently will look like the numbers broke. Fix it in a separate change with its own announcement.

## How to verify

No test suite exists. Do this by hand against a **staging database restored from a production dump**.

**1. Pick a real divergent shipment.** Find one whose per-line and per-shipment rounding disagree:

```sql
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
ORDER BY ABS(per_line - per_shipment) DESC
LIMIT 20;
```

Keep this list. It is the exact set of shipments whose ledger figure will move, and the `per_line` column is what they should read after the change.

**2. Before the change**, record for one client holding such a shipment:
- `GET /api/v1/shipments/{id}` → each item's `total`
- `GET /api/v1/clients/{client}/debit-ledger` → that shipment's `debit`, and `summary.total_debit`
- `GET /api/v1/clients/debits?search={shop_name}` → `total_debit`
- The stored hisob-faktura PDF (`shipments.invoice_path`, under `storage/app/public`)

**3. After the change**, all four must agree to the cent, and equal `per_line` from step 1.

**4. Check the SQL and PHP agree across the whole dataset.** In `php artisan tinker` on staging:

```php
$rows = DB::table('shipment_items as si')
    ->join('shipments as s', 's.id', '=', 'si.shipment_id')
    ->selectRaw('s.client_id, s.id as shipment_id')
    ->get()->groupBy('client_id');

foreach (array_slice($rows->keys()->all(), 0, 200) as $clientId) {
    $php = '0.00';
    foreach (\App\Models\ShipmentItem::whereIn('shipment_id', $rows[$clientId]->pluck('shipment_id'))
        ->with('variant.productColor.product', 'variant.productSize')->get() as $item) {
        $php = bcadd($php, $item->lineTotal(), 2);
    }
    $sql = \App\Models\Client::withTrashed()->find($clientId);   // see step 06
    // compare $php against the getSummaries total_debit for this client
    echo "$clientId php=$php\n";
}
```

Any client where PHP and SQL differ by a cent means the SQL expression is not equivalent — usually the `10000.0` DOUBLE issue. Fix it or fall back to PHP.

**5. Regenerate one PDF** (`ShipmentService::generateAndStoreHisobFaktura`) and check the money column against the API and the ledger.

**6. Confirm nothing went to float.** `grep -rn '(float)' app/Services/ClientDebitService.php app/Http/Resources/ShipmentItemResource.php` should return nothing on the money paths.

## Tell the users before you ship

Totals will change by a cent or two on the shipments identified in step 1. Existing PDFs on disk are **not** regenerated, so an old PDF may show 11.56 while the ledger now also shows 11.56 — that is the fix working. Give the office the step-1 list and let them know the ledger is moving to match the invoices, not the other way round.

Do not backfill or regenerate historical PDFs as part of this step.

## Rollback

Pure code change, no migration. `git revert` and deploy. The old formulas return and the old disagreement returns with them. Nothing on disk or in the database is touched, so rollback is clean at any point.

## Depends on / blocks

- **Depends on:** nothing. Start here.
- **Blocks:** nothing structurally, but do it first — it is the cheapest way to make the numbers self-consistent, and every later step is easier to verify once the four readouts agree.
- **Related:** step 06 changes `getSummaries` to use `withTrashed()` on clients. Both touch `ClientDebitService::getSummaries`; expect a small merge conflict if worked in parallel. Step 01 changes the `$debitSub` raw expression, step 06 changes the `Client::query()` at line 51 — different lines, but coordinate.
