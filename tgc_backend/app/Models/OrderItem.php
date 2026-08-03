<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class OrderItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'order_id',
        'product_variant_id',
        'quantity',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function productionBatchItems(): HasMany
    {
        return $this->hasMany(ProductionBatchItem::class, 'source_order_item_id');
    }

    /**
     * Lines from shipments that still count. A cancelled shipment's goods
     * came back, so its lines must not make this order item look shipped —
     * every caller here ("how much is left to ship", "is this order
     * complete") means the live total. Reach for shipmentItemsIncludingCanceled()
     * on the rare occasion you want the full history.
     */
    public function shipmentItems(): HasMany
    {
        return $this->hasMany(ShipmentItem::class, 'order_item_id')
            ->whereHas('shipment', fn ($q) => $q->whereNull('canceled_at'));
    }

    public function shipmentItemsIncludingCanceled(): HasMany
    {
        return $this->hasMany(ShipmentItem::class, 'order_item_id');
    }
}
