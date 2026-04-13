<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class ProductVariant extends Model
{
    protected $fillable = [
        'product_color_id',
        'product_size_id',
        'barcode_value',
        'sku_code',
    ];

    protected function casts(): array
    {
        return [
            'product_color_id' => 'integer',
            'product_size_id'  => 'integer',
        ];
    }

    // ── SKU generation ────────────────────────────────────────────────────────

    /**
     * Generate a human-readable SKU for a variant.
     *
     * Format: TGC-{NAME}-Q{quality_id}-T{type_id}-{COLOR}-{LxW}
     * Example: TGC-7126-Q1-T2-KREM-200x300
     */
    public static function generateSku(
        string $name,
        ?int $qualityId,
        ?int $typeId,
        string $colorName,
        ?ProductSize $size
    ): string {
        $sku = 'TGC-' . strtoupper(Str::slug($name, '_'));

        if ($qualityId) {
            $sku .= '-Q' . $qualityId;
        }
        if ($typeId) {
            $sku .= '-T' . $typeId;
        }

        $sku .= '-' . strtoupper(Str::slug($colorName, '_'));

        if ($size) {
            $sku .= '-' . $size->length . 'x' . $size->width;
        }

        return $sku;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productColor(): BelongsTo
    {
        return $this->belongsTo(ProductColor::class);
    }

    public function productSize(): BelongsTo
    {
        return $this->belongsTo(ProductSize::class);
    }

    public function warehouseDocumentItems(): HasMany
    {
        return $this->hasMany(WarehouseDocumentItem::class);
    }

    public function shipmentItems(): HasMany
    {
        return $this->hasMany(ShipmentItem::class);
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    // ── Convenience accessors ─────────────────────────────────────────────────

    /**
     * Shortcut to the parent product (through product_color).
     */
    public function product(): BelongsTo
    {
        // Eager-load via productColor.product — this accessor loads it if needed.
        return $this->productColor()->getRelated()->belongsTo(Product::class);
    }

    /**
     * Human-readable label: "Carpet Name (krem) 200x300".
     */
    public function label(): string
    {
        $pc   = $this->productColor;
        $name = $pc?->product?->name ?? "Product #?";
        $color = $pc?->color?->name ?? '';
        $size = $this->productSize
            ? " {$this->productSize->length}x{$this->productSize->width}"
            : '';

        return trim("{$name} ({$color}){$size}");
    }
}
