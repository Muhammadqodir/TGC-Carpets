<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Str;

class Product extends Model
{
    use HasFactory, SoftDeletes;

    const STATUS_ACTIVE   = 'active';
    const STATUS_ARCHIVED = 'archived';

    const STATUSES = [
        self::STATUS_ACTIVE,
        self::STATUS_ARCHIVED,
    ];

    const UNIT_PIECE = 'piece';
    const UNIT_M2    = 'm2';

    const UNITS = [
        self::UNIT_PIECE,
        self::UNIT_M2,
    ];

    protected $fillable = [
        'uuid',
        'name',
        'sku_code',
        'product_type_id',
        'product_quality_id',
        'color',
        'unit',
        'status',
        'image',
    ];

    protected function casts(): array
    {
        return [
            'product_type_id'    => 'integer',
            'product_quality_id' => 'integer',
            'deleted_at'         => 'datetime',
        ];
    }

    protected static function boot(): void
    {
        parent::boot();

        static::creating(function (Product $product): void {
            if (empty($product->uuid)) {
                $product->uuid = (string) Str::uuid();
            }
        });

        static::created(function (Product $product): void {
            if (empty($product->sku_code)) {
                $product->updateQuietly([
                    'sku_code' => 'TGC-' . str_pad($product->id, 5, '0', STR_PAD_LEFT),
                ]);
            }
        });
    }

    // ── Status helpers ────────────────────────────────────────────────────────

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productQuality(): BelongsTo
    {
        return $this->belongsTo(ProductQuality::class);
    }

    public function isArchived(): bool
    {
        return $this->status === self::STATUS_ARCHIVED;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productType(): BelongsTo
    {
        return $this->belongsTo(ProductType::class);
    }

    public function warehouseDocumentItems(): HasMany
    {
        return $this->hasMany(WarehouseDocumentItem::class);
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    public function saleItems(): HasMany
    {
        return $this->hasMany(SaleItem::class);
    }
}
