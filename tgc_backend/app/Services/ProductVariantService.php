<?php

namespace App\Services;

use App\Models\ProductVariant;
use Illuminate\Support\Facades\DB;

class ProductVariantService
{
    /**
     * Find the unique variant for a (product_color, size) pair, or create it
     * lazily if it does not yet exist.
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

            $variant = ProductVariant::create([
                'product_color_id' => $productColorId,
                'product_size_id'  => $sizeId,
            ]);

            $variant->load(['productColor.product', 'productColor.color', 'productSize']);
            $pc = $variant->productColor;

            $variant->update([
                'barcode_value' => 'TGC-VAR-' . str_pad($variant->id, 8, '0', STR_PAD_LEFT),
                'sku_code'      => ProductVariant::generateSku(
                    $pc->product->name,
                    $pc->product->product_quality_id,
                    $pc->product->product_type_id,
                    $pc->color->name,
                    $variant->productSize,
                ),
            ]);

            return $variant->fresh();
        });
    }
}
