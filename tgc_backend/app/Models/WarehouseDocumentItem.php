<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class WarehouseDocumentItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'warehouse_document_id',
        'product_variant_id',
        'quantity',
        'source_type',
        'source_id',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'quantity'           => 'integer',
            'product_variant_id' => 'integer',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function warehouseDocument(): BelongsTo
    {
        return $this->belongsTo(WarehouseDocument::class);
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    /**
     * Polymorphic source that triggered this item.
     * source_type: 'shipment_item' | 'production_batch_item'
     */
    public function source(): MorphTo
    {
        return $this->morphTo('source', 'source_type', 'source_id');
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }
}
