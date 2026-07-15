# 04 — Currency, VAT, discount and exchange rate

Every number in the system is a bare decimal that everyone has agreed to imagine is US dollars.

**Severity: High / Effort: 2 weeks / Safe on live: No — schema plus money semantics; stage it, backfill carefully, ship behind a default**

## Why this matters

Verified by grep across `tgc_backend/app`, `tgc_backend/database/migrations` and `tgc_backend/resources/views`: there is **no** `currency`, `exchange_rate`, `vat`, `tax`, `nds` or `discount` column, constant, config key or line of code anywhere in the backend. Not one hit.

The complete set of money columns in the system is two:

| Column | Type | Migration |
|---|---|---|
| `payments.amount` | `decimal(14,2)` | `2026_04_15_000001_create_payments_table.php` line 16 |
| `shipment_items.price` | `decimal(12,2)` | `2026_04_13_000005_create_shipment_items_table.php` line 27 |

Both are bare numbers with no unit attached. `shipment_items.total` existed and was **dropped** by `2026_04_16_000001_drop_total_from_shipment_items_table.php`; the total is now computed at render time by `ShipmentItemResource::computeTotal()` (`app/Http/Resources/ShipmentItemResource.php` lines 48–63).

The only place a currency is named anywhere is a hardcoded string in a PDF template. `resources/views/pdf/shipment_hisob_faktura.blade.php` line 205:

```blade
<th class="right" style="width: 10%;">Jami ($)</th>
```

That `$` is the entire currency model. It is a column heading. (Line 204 is `Narx ($)`, the same hardcoding; line 203 is `Jami m²`, line 284 is `Jami summa` — the total, also unlabelled. `resources/views/pdf/shipment_invoice.blade.php` carries **no money column at all** — its columns stop at `Jami m²` (line 209) and quantity, so it names no currency.)

### Orders carry no money at all

`orders`, `order_items` and `products` have **no price column**. Grep for `price` across the migrations returns hits only in `shipment_items` and `payments`. An order is a promise to deliver carpets with no monetary value attached to it. You cannot answer "what is this order worth" from the order.

Price is typed fresh, by a human, at shipment time. It is prefilled from `ShipmentService::getLastPrice()` (`app/Services/ShipmentService.php` line 389):

```php
public function getLastPrice(int $variantId, int $clientId): ?float
{
    $price = ShipmentItem::whereHas(
        'shipment',
        fn ($q) => $q->where('client_id', $clientId)
    )
        ->where('product_variant_id', $variantId)
        ->orderByDesc('created_at')
        ->value('price');

    return $price !== null ? (float) $price : null;
}
```

So the price of a carpet is "whatever we charged this client last time, unless someone types something else". There is no price list, no agreed order value, and no record of *why* a price changed. Note this is `?float` — money crossing a float boundary, which is its own Phase 1 problem.

### The concrete failure

The factory sells in more than one currency, or will. Today:

- A client agrees 500 carpets at 1,200,000 UZS each. Someone types `1200000` into `price`. The invoice prints `Jami ($) 600,000,000`. The debit ledger charges the client 600,000,000 of the same imaginary unit. It nets out only because *everything* is consistently wrong, and it stays that way exactly until one client is billed in USD and another in UZS. Then `clients.debits` sums 12,000 USD and 600,000,000 UZS into one number: 600,012,000 of nothing.
- A 15% discount is applied by typing a smaller number into `price`. The 15% is now unrecoverable — there is no record a discount happened, so nobody can report on discounting, and the "last price" prefill silently propagates the discounted figure to the next shipment forever. That is a real mechanism by which a one-off concession becomes a permanent price cut. `getLastPrice()` makes every discount sticky.
- VAT does not exist, so an invoice that must show a VAT line cannot be produced. The current workaround is presumably to bake it into the price, which corrupts the same field again.

## Files to change

- new migration: `currency` + `exchange_rate` on `shipments` and `payments`
- new migration: `vat_rate` / `vat_amount` and `discount_type` / `discount_value` / `discount_amount` on `shipments` and `shipment_items`
- `tgc_backend/app/Models/Shipment.php`, `ShipmentItem.php`, `Payment.php`
- `tgc_backend/app/Http/Resources/ShipmentItemResource.php` — `computeTotal()` lines 48–63
- `tgc_backend/app/Http/Resources/ShipmentResource.php`
- `tgc_backend/app/Services/ShipmentService.php` — `getLastPrice()` line 389
- `tgc_backend/app/Services/ClientDebitService.php` — the ledger that must agree with the invoice
- `tgc_backend/app/Http/Requests/Shipment/StoreShipmentRequest.php`
- `tgc_backend/resources/views/pdf/shipment_hisob_faktura.blade.php` — lines 203, 204, 205, 284
- `tgc_backend/resources/views/pdf/shipment_invoice.blade.php` — no money columns today; only in scope if a currency figure is added to it
- new `tgc_backend/config/money.php` — base currency, allowed currencies, rounding mode
- client: shipment create/edit forms, invoice preview, client debit views

## The change

### 1. Currency and exchange rate

```sql
ALTER TABLE shipments
  ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'USD' AFTER client_id,
  ADD COLUMN exchange_rate DECIMAL(18,8) NOT NULL DEFAULT 1 AFTER currency;

ALTER TABLE payments
  ADD COLUMN currency CHAR(3) NOT NULL DEFAULT 'USD' AFTER amount,
  ADD COLUMN exchange_rate DECIMAL(18,8) NOT NULL DEFAULT 1 AFTER currency;
```

`DEFAULT 'USD'` **is** the backfill for existing rows, and it is the right one: every existing number was already assumed to be USD, so declaring that assumption changes no value. Verify nothing is obviously non-USD first:

```sql
SELECT MIN(price), MAX(price), AVG(price) FROM shipment_items;
SELECT MIN(amount), MAX(amount), AVG(amount) FROM payments;
```

If a max price is in the millions, someone has already typed UZS into a field the invoice labels `$`, and you have a data-correction job before a schema job. Do not skip this check — find out before you formalise the wrong unit.

Rules:
- `currency` is the currency the document is **transacted** in. It is what the invoice prints and what the client actually owes.
- `exchange_rate` is `1 <currency> = X <base>`, captured **at document time** and frozen. Never look it up at read time — a paid invoice must not change value because a rate moved. This is the single most important property here.
- base currency lives in `config/money.php`, set to `USD`. Every cross-currency aggregate (client debit totals, dashboards) converts to base using each row's stored rate.
- `decimal(18,8)` handles UZS↔USD (rate ≈ 0.00008) without losing precision.

Store the rate even when `currency` equals base — always `1`. Uniformity beats a nullable column and a branch at every read.

### 2. Discount

Put discount at the **line** level. A header-level discount has to be apportioned across lines to produce a per-line total, and apportionment is where cents vanish.

```sql
ALTER TABLE shipment_items
  ADD COLUMN discount_type ENUM('none','percent','amount') NOT NULL DEFAULT 'none' AFTER price,
  ADD COLUMN discount_value DECIMAL(12,4) NOT NULL DEFAULT 0 AFTER discount_type,
  ADD COLUMN discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0 AFTER discount_value;
```

- `discount_value` is the input: `15` for 15%, or `50.00` for a flat 50 off.
- `discount_amount` is the computed, frozen cash value in the shipment currency. Store it. Recomputing a discount at read time means an old invoice reprints differently after a rounding change.
- `decimal(12,4)` on `discount_value` allows 12.5%.

If the factory genuinely gives whole-invoice discounts, add `discount_type`/`discount_value` to `shipments` too, apportion to lines by line subtotal using a largest-remainder method, and store the result in each line's `discount_amount`. Do not print an apportioned discount that does not sum to the header figure — a one-cent mismatch on an invoice destroys trust in the whole document.

### 3. VAT

VAT is a **header** concern here — one rate per invoice, which matches how the `hisob-faktura` prints.

```sql
ALTER TABLE shipments
  ADD COLUMN vat_rate DECIMAL(6,4) NOT NULL DEFAULT 0 AFTER exchange_rate,
  ADD COLUMN vat_amount DECIMAL(14,2) NOT NULL DEFAULT 0 AFTER vat_rate;
```

`DEFAULT 0` backfills every historical shipment to "no VAT", which is what they were.

If lines are ever taxed at different rates, move `vat_rate` to `shipment_items` before shipping. Migrating header→line later means rewriting every stored total. Ask now.

### 4. Where rounding happens — the ordering that matters

This is the part that must be written down once and never improvised. The current formula (`ShipmentItemResource::computeTotal()`, lines 48–63):

```php
if ($unit === 'm2') {
    $sqm = $size->length * $size->width * $qty / 10000.0;
    return round($price * $sqm, 2);
}
return round($price * $qty, 2);
```

Intended sequence, **per line**:

```
1. gross      = price × quantity            (m² lines: price × sqm, sqm = L × W × qty / 10000)
2. gross      = round(gross, 2)             ← round ONCE here, in the shipment currency
3. discount   = discount_type = 'percent'
                  ? round(gross × discount_value / 100, 2)
                  : min(discount_value, gross)
4. net        = gross − discount            (exact; both operands already 2dp)
5. store gross, discount_amount, net on the line
```

Then, **per shipment**:

```
6. subtotal   = SUM(line net)               (exact; all operands 2dp)
7. vat_amount = round(subtotal × vat_rate, 2)
8. total      = subtotal + vat_amount       (exact)
9. base_total = round(total × exchange_rate, 2)   ← for cross-currency aggregates only
```

The rules behind that:

- **Round once per line, at step 2, before discount.** Not at the end. If you round only the final total, the printed line totals will not sum to the printed grand total and the invoice is visibly wrong.
- **VAT applies to the discounted subtotal**, not to gross. Confirm against Uzbek tax rules before shipping — this is a legal question, not an engineering one, and getting it backwards is a compliance problem, not a bug. Write the answer in `config/money.php` as a comment with a date.
- **Sum rounded lines; never round a sum of unrounded lines.** Steps 4, 6 and 8 add already-rounded values, so they are exact and the invoice foots.
- **Convert last** (step 9), never mid-calculation. Converting per line then summing introduces a rounding error per line; on a 500-line shipment that is real money.
- **The m² calculation is where precision dies.** `L × W × qty / 10000.0` is float division today. A 200×300 carpet is 6 m² exactly, but 175×265 is 4.6375 m², and `price × 4.6375` lands on a half-cent constantly. Whatever half-cent rule Phase 1 picks (banker's vs half-up) must be applied here and asserted by the boundary tests in `01-tests-and-ci.md`.
- **`round()` on floats is not good enough for money.** Phase 1 should have moved this to integer minor units or `bcmath`. If it has not, do not layer VAT and discount on top of float arithmetic — you will be debugging cents forever. This is the hard dependency described below.

### 5. `getLastPrice()` must become currency-aware

Line 389 returns a bare `?float` with no currency. After this change it must return price **and** currency, and must not prefill a price from a shipment in a different currency — offering last time's `1200000` UZS as this time's USD price is a catastrophic default.

```php
public function getLastPrice(int $variantId, int $clientId, string $currency): ?string
{
    return ShipmentItem::whereHas(
        'shipment',
        fn ($q) => $q->where('client_id', $clientId)->where('currency', $currency)
    )
        ->where('product_variant_id', $variantId)
        ->orderByDesc('created_at')
        ->value('price');
}
```

Also decide whether the prefill should use `price` (pre-discount) or the net. **Use `price`.** Prefilling the discounted figure is the mechanism that makes one-off concessions permanent, described above. This one-line decision is arguably worth more than the rest of the file.

### 6. The PDF templates

`shipment_hisob_faktura.blade.php` line 205 becomes dynamic:

```blade
<th class="right" style="width: 10%;">Jami ({{ $shipment->currency_symbol }})</th>
```

Line 204 (`Narx ($)`) needs the same treatment. Add VAT and discount rows near the `Jami summa` total at line 284. If the printed layout has a fixed height, adding rows may overflow the page — check the rendered output, not just the markup. `shipment_invoice.blade.php` needs no currency change — it prints quantities and m² only, with no money column.

A `hisob-faktura` is a legal document in Uzbekistan. If VAT appears on it, the format is likely prescribed. Have someone who has filed one look at the output before it goes to a client.

## How to verify

1. Existing shipments: `currency = 'USD'`, `exchange_rate = 1`, `vat_rate = 0`, `discount_amount = 0`. Every historical invoice PDF **reprints byte-identically** to before the change. Diff a dozen. This is the acceptance test for the backfill — if an old invoice changes by a cent, stop.
2. New USD shipment, no VAT, no discount → totals identical to the old formula. Compare against a pre-change shipment with the same numbers.
3. UZS shipment at rate 0.00008: invoice prints UZS with a UZS heading; the client debit ledger converted to base shows the USD equivalent; both agree with a hand calculation.
4. 15% line discount: `discount_amount` stored, printed, and `net = gross − discount`. Change the rate later — the old shipment's stored `discount_amount` does not move.
5. VAT 12% on a discounted subtotal: `vat_amount = round(subtotal × 0.12, 2)`, `total = subtotal + vat`. Confirm against the tax rule, not against your intuition.
6. **Sum of printed line totals equals the printed grand total** on a 50-line shipment with an odd-sized m² product (175×265). This is the test that catches the rounding-order mistakes.
7. Move the exchange rate. Every previously-created shipment's base value is unchanged. If any moves, you are looking the rate up at read time — fix it.
8. `getLastPrice()` on a client with both USD and UZS history prefills the right one and never crosses currencies.
9. Client debit total for a client with mixed-currency shipments is a single, correct base-currency figure.

## Rollback

The columns are additive with defaults matching current behaviour, so a code-only revert is safe while every row is still `USD` / rate 1 / VAT 0 / discount 0: old code ignores the new columns and behaves exactly as before. Keep the columns; drop only if you abandon the work.

**The rollback window closes the moment the first non-USD or VAT-bearing shipment is created.** After that, reverting the code makes the invoice print a UZS number under a `$` heading and the debit ledger add currencies together. Before enabling a second currency in production, be sure. Gate it: keep the currency selector hidden in the client until items 1–9 above all pass, so the window stays open through the whole rollout.

## Depends on / blocks

- **Hard dependency on the Phase 1 single-money-formula work. This must land after it.** Phase 1 consolidates the money calculation into one place and settles float-vs-decimal and the half-cent rule. Adding VAT, discount and conversion to a formula that is about to be rewritten means doing the work twice and reconciling two sets of rounding bugs. If Phase 1 has not landed, stop and do it first.
- **Depends on `01-tests-and-ci.md`**, specifically the money boundary tests. Those tests exist to make this change survivable. Extend them with a VAT/discount/conversion case per rounding boundary as part of this work.
- **Related to `06-audit-log.md`.** A price change is a money mutation and must be auditable — "who gave this client 15% off" is exactly the question the audit log exists to answer. Doing 04 first is fine; ensure the new columns are covered when 06 lands.
- **Blocks nothing in Phase 3**, but blocks any future price-list, quotation or margin-reporting work. An order carries no monetary value today; until that changes, "what is our order book worth" has no answer. Adding prices to `orders`/`order_items` is the natural next step and is deliberately **not** in this file — it is a separate design decision about whether an order is a priced agreement or just a production instruction. Decide it before someone adds a `price` column to `order_items` by reflex.
