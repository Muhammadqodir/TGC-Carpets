<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;
use App\Services\ProductImageThumbnailer;

class ProductColor extends Model
{
    use HasFactory;

    protected static function booted(): void
    {
        // Keep the list-screen thumbnail in step with the photo, whichever
        // controller uploaded it (product colours, product import, …).
        static::saved(function (ProductColor $pc) {
            if (! $pc->wasChanged('image') && ! $pc->wasRecentlyCreated) {
                return;
            }
            $old = $pc->getOriginal('image');
            if ($old && $old !== $pc->image) {
                ProductImageThumbnailer::delete($old);
            }
            if ($pc->image) {
                ProductImageThumbnailer::generate($pc->image, force: true);
            }
        });

        static::deleted(fn (ProductColor $pc) => ProductImageThumbnailer::delete($pc->image));
    }

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
        // withTrashed: a hidden colour still belongs to products that use it.
        return $this->belongsTo(Color::class)->withTrashed();
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

    /** Small JPEG for list screens; null until generated (fall back to the original). */
    public function thumbUrl(): ?string
    {
        return ProductImageThumbnailer::url($this->image);
    }

    public function label(): string
    {
        $productName = $this->product?->name ?? "Product #{$this->product_id}";
        $colorName   = $this->color?->name   ?? '?';

        return "{$productName} ({$colorName})";
    }
}
