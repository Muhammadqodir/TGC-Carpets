<?php

namespace App\Models;

use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductVariant;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductionBatchItem extends Model
{
    const SOURCE_ORDER_ITEM    = 'order_item';
    const SOURCE_STOCK_REQUEST = 'stock_request';
    const SOURCE_MANUAL        = 'manual';

    const SOURCE_TYPES = [
        self::SOURCE_ORDER_ITEM,
        self::SOURCE_STOCK_REQUEST,
        self::SOURCE_MANUAL,
    ];

    protected $fillable = [
        'production_batch_id',
        'source_type',
        'source_order_item_id',
        'product_variant_id',
        'planned_quantity',
        'produced_quantity',
        'defect_quantity',
        'warehouse_received_quantity',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'planned_quantity'             => 'integer',
            'produced_quantity'            => 'integer',
            'defect_quantity'              => 'integer',
            'warehouse_received_quantity'  => 'integer',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productionBatch(): BelongsTo
    {
        return $this->belongsTo(ProductionBatch::class);
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function sourceOrderItem(): BelongsTo
    {
        return $this->belongsTo(OrderItem::class, 'source_order_item_id');
    }
}
