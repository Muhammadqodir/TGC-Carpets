# Fix the m² columns on the `hisob-faktura` invoice

`$sqm` already includes quantity, then the total column multiplies by quantity again — so the invoice shows qty² square metres and contradicts its own grand total.

**Severity:** High · **Effort:** 30 min · **Safe on live:** Yes — presentation only, no data or money changes

**Finding:** CALC-4 · **Depends on:** nothing

## Why this matters

This document goes to the client. It currently disagrees with itself on the same page, which is the kind of thing that costs you an argument you should win.

`resources/views/pdf/shipment_hisob_faktura.blade.php` — the headers declare two different columns:

```blade
<th class="right" style="width: 10%;">m²</th>          {{-- per unit --}}
<th class="right" style="width: 8%;">Miqdor</th>
<th class="right" style="width: 10%;">Jami m²</th>     {{-- total --}}
```

But `$sqm` is computed **already including `$qty`**:

```blade
$sqm = ($size && $unit === 'm2')
    ? round(($size->length * $size->width * $qty) / 10000, 4)   {{-- ← $qty is in here --}}
    : 0;
```

and then it is printed as the *per-unit* figure:

```blade
<td class="right">
    @if ($sqm > 0)
        {{ number_format($sqm, 2) }} m²        {{-- ← already a total, labelled per-unit --}}
    @endif
</td>
```

and multiplied by `$qty` **again** for the *total*:

```blade
<td class="right">
    @if ($sqm > 0)
        {{ number_format($sqm * $qty, 2) }} m²  {{-- ← qty² --}}
    @endif
</td>
```

### Failure scenario

60 × 110 cm carpet, qty 10, price 12.00/m². True per-unit area is 0.66 m²; true total is 6.60 m².

| Column | Shows | Should show |
|---|---|---|
| `m²` | **6.60** | 0.66 |
| `Miqdor` | 10 | 10 |
| `Jami m²` | **66.00** | 6.60 |
| `Narx ($)` | 12.00 | 12.00 |
| `Jami ($)` | 79.20 ✓ | 79.20 |
| `Umumiy m²` (grand total) | 6.60 ✓ | 6.60 |

So the money is **correct** and the grand total is **correct** — only the two m² columns are wrong. The invoice tells the client the line is 66 m² while the footer says the whole shipment is 6.60 m².

### Proof it's a bug, not a convention

The sibling template `resources/views/pdf/shipment_invoice.blade.php` does it correctly — per-unit as `($size->length * $size->width) / 10000`, total as the qty-inclusive figure. Two templates, same data, different answers.

## The change

Separate the two quantities and give them honest names. In `shipment_hisob_faktura.blade.php`, inside the `@foreach` `@php` block:

```blade
{{-- per unit --}}
$sqmPerUnit = ($size && $unit === 'm2')
    ? ($size->length * $size->width) / 10000
    : 0;

{{-- line total --}}
$sqmTotal = $sqmPerUnit * $qty;

$lineTotal = ($unit === 'm2' && $sqmTotal > 0)
    ? round($price * $sqmTotal, 2)
    : round($price * $qty, 2);

$grandTotalSqm   += $sqmTotal;
$grandTotalQty   += $qty;
$grandTotalPrice += $lineTotal;
```

Then in the row:

```blade
{{-- m² column --}}
<td class="right">
    @if ($sqmPerUnit > 0)
        {{ number_format($sqmPerUnit, 2) }} m²
    @else
        —
    @endif
</td>

{{-- Jami m² column --}}
<td class="right">
    @if ($sqmTotal > 0)
        {{ number_format($sqmTotal, 2) }} m²
    @else
        —
    @endif
</td>
```

Note `$lineTotal` and `$grandTotalSqm` come out **numerically identical** to today — you are renaming `$sqm` to `$sqmTotal` and introducing `$sqmPerUnit`. Money must not move. If it does, you've made a mistake.

The `round($sqm, 4)` in the current code is harmless (`L × W × qty` is an integer, so `/10000` always terminates at 4 dp) — dropping it changes nothing, but keep the rounding on `$lineTotal`.

### Don't touch the money formula here

You will notice `$lineTotal` here is a fourth copy of the shipment line-total formula (CALC-3). Leave it. `phase-1/01` replaces all four copies with one shared method. Doing it now would turn a 30-minute presentation fix into a two-day refactor and delay phase 0.

Add a comment pointing at it:

```blade
{{-- TODO: replace with ShipmentItem::lineTotal() — see instructions/phase-1/01 --}}
```

## How to verify

1. Find a shipment with an m² product where `quantity > 1` — the bug is invisible at qty 1, since qty² = qty:
   ```sql
   SELECT si.id, si.shipment_id, si.quantity, si.price, ps.length, ps.width
   FROM shipment_items si
   JOIN product_variants pv ON pv.id = si.product_variant_id
   JOIN product_sizes ps ON ps.id = pv.product_size_id
   WHERE si.quantity > 1
   LIMIT 5;
   ```
2. Generate the PDF before and after. Compare side by side.
3. Check by hand: `m² × Miqdor` must equal `Jami m²` on every row. Today it doesn't.
4. Check the column of `Jami m²` values sums to the `Umumiy m²` footer. Today it doesn't.
5. **Confirm `Jami ($)` and the money grand total are byte-for-byte unchanged.** This is the important one — if any money moved, revert and re-read the change.
6. Check a `piece`-unit product too (`$unit !== 'm2'`) — those rows show `—` in both m² columns and must stay that way.

## Rollback

Revert the commit. Nothing is stored — the template is rendered on demand.

## Note

Invoices already sent to clients have the wrong m² columns. The **money on them was right**, so there is nothing to re-bill and no financial correction to make. If a client has ever queried the m² figures, this is the explanation. Regenerating an old shipment's PDF after this fix will produce different m² columns for the same shipment — worth telling the owner before they notice.
