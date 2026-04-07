<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;

class ProductColor extends Model
{
    protected $fillable = [
        'product_id',
        'color_id',
        'image',
    ];

    protected function casts(): array
    {
        return [
            'product_id' => 'integer',
            'color_id'   => 'integer',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function color(): BelongsTo
    {
        return $this->belongsTo(Color::class);
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ProductVariant::class);
    }

    public function stockMovements(): HasManyThrough
    {
        return $this->hasManyThrough(
            StockMovement::class,
            ProductVariant::class,
            'product_color_id',
            'product_variant_id',
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    public function label(): string
    {
        $productName = $this->product?->name ?? "Product #{$this->product_id}";
        $colorName   = $this->color?->name   ?? '?';

        return "{$productName} ({$colorName})";
    }
}
