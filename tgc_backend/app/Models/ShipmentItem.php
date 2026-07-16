<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ShipmentItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'shipment_id',
        'order_item_id',
        'product_variant_id',
        'quantity',
        'price',
        'discount_type',
        'discount_value',
        'discount_amount',
    ];

    protected function casts(): array
    {
        return [
            'quantity'        => 'integer',
            'price'           => 'decimal:2',
            'discount_value'  => 'decimal:4',
            'discount_amount' => 'decimal:2',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }

    public function orderItem(): BelongsTo
    {
        return $this->belongsTo(OrderItem::class);
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function warehouseDocumentItems(): HasMany
    {
        return $this->hasMany(WarehouseDocumentItem::class, 'source_id')
            ->where('source_type', 'shipment_item');
    }

    /**
     * The pre-discount line value, rounded to 2dp exactly ONCE, here — not
     * at the end. Discount is computed against this already-rounded
     * figure, so printed line totals sum to the printed grand total. See
     * instructions/phase-3/04-currency-vat-discount.md "Where rounding
     * happens".
     *
     * m2 products:  price × length × width × quantity / 10000
     * otherwise:    price × quantity
     *
     * Requires: variant.productColor.product and variant.productSize to be loaded
     * (or they will lazy-load — acceptable, but eager-load in loops).
     */
    public function grossAmount(): string
    {
        // Cast attribute, not getRawOriginal(): the latter reads $original,
        // which Eloquent syncs from an EMPTY array before fill() runs in the
        // constructor — so it's always null on a `new ShipmentItem([...])`
        // that hasn't been saved/loaded yet, silently zeroing this formula.
        $price = (string) $this->price;
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

    /**
     * discount_type = 'percent': round(gross × discount_value / 100, 2).
     * discount_type = 'amount':  min(discount_value, gross) — never lets a
     * flat discount push the line negative.
     * discount_type = 'none' (the default for every row that predates this
     * column, and for every row created without a discount): always 0,
     * which is what makes lineTotal() below byte-identical to the old
     * formula for all existing and undiscounted data.
     */
    public function discountAmount(): string
    {
        $type  = $this->discount_type ?? 'none';
        $value = (string) ($this->discount_value ?? '0');

        if ($type === 'none' || bccomp($value, '0', 4) <= 0) {
            return '0.00';
        }

        $gross = $this->grossAmount();

        if ($type === 'percent') {
            return $this->round2(bcdiv(bcmul($gross, $value, 8), '100', 8));
        }

        // 'amount'
        $flat = $this->round2($value);

        return bccomp($flat, $gross, 2) > 0 ? $gross : $flat;
    }

    /**
     * The authoritative money value for this line: gross minus discount,
     * both already 2dp, so the subtraction is exact. This is what every
     * existing caller (ClientDebitService, the invoice PDFs) means by
     * "the line total" — unchanged in output for any row with no
     * discount, which is every row that existed before this column did.
     */
    public function lineTotal(): string
    {
        return bcsub($this->grossAmount(), $this->discountAmount(), 2);
    }

    /** bcmath truncates; this rounds half-up, which is what round() did. */
    private function round2(string $value): string
    {
        $add = str_starts_with($value, '-') ? '-0.005' : '0.005';

        return bcadd($value, $add, 2);
    }
}
