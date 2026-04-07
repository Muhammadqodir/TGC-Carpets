<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;
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
        'product_type_id',
        'product_quality_id',
        'unit',
        'status',
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

    }

    // ── Status helpers ────────────────────────────────────────────────────────

    public function isActive(): bool
    {
        return $this->status === self::STATUS_ACTIVE;
    }

    public function isArchived(): bool
    {
        return $this->status === self::STATUS_ARCHIVED;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productQuality(): BelongsTo
    {
        return $this->belongsTo(ProductQuality::class);
    }

    public function productType(): BelongsTo
    {
        return $this->belongsTo(ProductType::class);
    }

    public function productColors(): HasMany
    {
        return $this->hasMany(ProductColor::class);
    }

    public function variants(): HasManyThrough
    {
        return $this->hasManyThrough(
            ProductVariant::class,
            ProductColor::class,
            'product_id',
            'product_color_id',
        );
    }

    public function stockMovements(): HasManyThrough
    {
        // Two-level through: Product → ProductColor → ProductVariant → StockMovement
        // Laravel's hasManyThrough only supports one intermediate table,
        // so we use a raw subquery for aggregation where needed.
        // For the relationship, go through product_colors to product_variants.
        return $this->hasManyThrough(
            ProductVariant::class,
            ProductColor::class,
            'product_id',
            'product_color_id',
        );
    }
}
