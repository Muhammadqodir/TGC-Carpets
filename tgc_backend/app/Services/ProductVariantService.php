<?php

namespace App\Services;

use App\Models\ProductColor;
use App\Models\ProductSize;
use App\Models\ProductVariant;
use Illuminate\Support\Facades\DB;

class ProductVariantService
{
    /**
     * Find the unique variant for a (product_color, size) pair, or create it
     * lazily if it does not yet exist.
     *
     * SKU is computed before the INSERT so sku_code (NOT NULL) is satisfied in
     * a single statement.  Only barcode_value — which embeds the new row's ID —
     * requires a subsequent UPDATE.
     *
     * A pessimistic lock inside a transaction protects against a race condition
     * for the NULL-size case (MySQL UNIQUE indexes allow multiple NULL values in
     * a composite key, so application-level enforcement is required there).
     */
    public function findOrCreate(int $productColorId, ?int $sizeId): ProductVariant
    {
        return DB::transaction(function () use ($productColorId, $sizeId): ProductVariant {
            $variant = ProductVariant::where('product_color_id', $productColorId)
                ->when(
                    $sizeId !== null,
                    fn ($q) => $q->where('product_size_id', $sizeId),
                    fn ($q) => $q->whereNull('product_size_id'),
                )
                ->lockForUpdate()
                ->first();

            if ($variant) {
                return $variant;
            }

            // Load relationships before INSERT so we can compute sku_code upfront.
            $pc   = ProductColor::with(['product', 'color'])->findOrFail($productColorId);
            $size = $sizeId ? ProductSize::findOrFail($sizeId) : null;

            $variant = ProductVariant::create([
                'product_color_id' => $productColorId,
                'product_size_id'  => $sizeId,
                'sku_code'         => ProductVariant::generateSku(
                    $pc->product->name,
                    $pc->product->product_quality_id,
                    $pc->product->product_type_id,
                    $pc->color->name,
                    $size,
                ),
            ]);

            // barcode_value embeds the auto-incremented ID, so it must be set after INSERT.
            $variant->update([
                'barcode_value' => 'TGC-' . str_pad($variant->id, 8, '0', STR_PAD_LEFT),
            ]);

            return $variant->fresh();
        });
    }
}
