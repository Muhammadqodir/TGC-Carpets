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
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'price'    => 'decimal:2',
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
}
