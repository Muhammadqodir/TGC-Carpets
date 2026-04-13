<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use App\Models\ProductionBatchItem;

class WarehouseDocumentItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'warehouse_document_id',
        'product_variant_id',
        'quantity',
        'production_batch_item_id',
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

    public function productionBatchItem(): BelongsTo
    {
        return $this->belongsTo(ProductionBatchItem::class);
    }
}
