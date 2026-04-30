<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class StockMovement extends Model
{
    use HasFactory;

    const TYPE_IN  = 'in';
    const TYPE_OUT = 'out';

    const TYPES = [
        self::TYPE_IN,
        self::TYPE_OUT,
    ];

    protected $fillable = [
        'uuid',
        'product_variant_id',
        'warehouse_document_item_id',
        'user_id',
        'movement_type',
        'quantity',
        'movement_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'quantity'           => 'integer',
            'movement_date'      => 'datetime',
            'product_variant_id' => 'integer',
        ];
    }

    protected static function boot(): void
    {
        parent::boot();

        static::creating(function (StockMovement $movement): void {
            if (empty($movement->uuid)) {
                $movement->uuid = (string) Str::uuid();
            }
        });
    }

    // ── Direction helpers ─────────────────────────────────────────────────────

    /**
     * Returns true for movement types that add stock.
     */
    public function isIncoming(): bool
    {
        return $this->movement_type === self::TYPE_IN;
    }

    /**
     * Returns true for movement types that reduce stock.
     */
    public function isOutgoing(): bool
    {
        return $this->movement_type === self::TYPE_OUT;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function warehouseDocumentItem(): BelongsTo
    {
        return $this->belongsTo(WarehouseDocumentItem::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
