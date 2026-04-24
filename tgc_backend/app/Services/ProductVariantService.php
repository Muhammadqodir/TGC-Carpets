<?php

namespace App\Services;

use App\Models\ProductColor;
use App\Models\ProductSize;
use App\Models\ProductVariant;
use Illuminate\Database\UniqueConstraintViolationException;
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
     * The optimistic approach: attempt INSERT first, catch the unique violation
     * and return the row that already exists.  This is safe under concurrent
     * requests and avoids the SELECT→INSERT race that `lockForUpdate` cannot
     * prevent for the "no row yet" case (MySQL UNIQUE allows multiple NULLs in
     * a composite index, so the DB-level constraint is the only reliable guard).
     */
    public function findOrCreate(int $productColorId, ?int $sizeId): ProductVariant
    {
        // Fast path — variant already exists.
        $existing = ProductVariant::where('product_color_id', $productColorId)
            ->when(
                $sizeId !== null,
                fn ($q) => $q->where('product_size_id', $sizeId),
                fn ($q) => $q->whereNull('product_size_id'),
            )
            ->first();

        if ($existing) {
            return $existing;
        }

        // Load relationships to compute sku_code upfront.
        $pc   = ProductColor::with(['product', 'color'])->findOrFail($productColorId);
        $size = $sizeId ? ProductSize::findOrFail($sizeId) : null;

        $sku = ProductVariant::generateSku(
            $pc->product->name,
            $pc->product->product_quality_id,
            $pc->product->product_type_id,
            $pc->color->name,
            $size,
        );

        try {
            $variant = DB::transaction(function () use ($productColorId, $sizeId, $sku): ProductVariant {
                $variant = ProductVariant::create([
                    'product_color_id' => $productColorId,
                    'product_size_id'  => $sizeId,
                    'sku_code'         => $sku,
                ]);

                // barcode_value embeds the auto-incremented ID, set after INSERT.
                $variant->update([
                    'barcode_value' => 'TGC-' . str_pad($variant->id, 8, '0', STR_PAD_LEFT),
                ]);

                return $variant->fresh();
            });
        } catch (UniqueConstraintViolationException) {
            // Another request inserted the same variant concurrently — fetch it.
            $variant = ProductVariant::where('product_color_id', $productColorId)
                ->when(
                    $sizeId !== null,
                    fn ($q) => $q->where('product_size_id', $sizeId),
                    fn ($q) => $q->whereNull('product_size_id'),
                )
                ->firstOrFail();
        }

        return $variant;
    }
}
