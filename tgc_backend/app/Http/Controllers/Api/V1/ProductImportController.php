<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Color;
use App\Models\Product;
use App\Models\ProductColor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ProductImportController extends Controller
{
    /**
     * Import a single product-color entry.
     *
     * Finds or creates the product (matched on name + quality + type),
     * finds or creates the color, then creates the product-color if it
     * does not already exist.
     */
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'product_quality_id' => ['nullable', 'integer', 'exists:product_qualities,id'],
            'product_type_id'    => ['nullable', 'integer', 'exists:product_types,id'],
            'name'               => ['required', 'string', 'max:255'],
            'color'              => ['required', 'string', 'max:100'],
            'image'              => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ]);

        $qualityId   = $request->input('product_quality_id');
        $typeId      = $request->input('product_type_id');
        $productName = trim($request->input('name'));
        $colorName   = trim($request->input('color'));

        // Upload image before the transaction — filesystem ops cannot be rolled back.
        $imagePath = null;
        if ($request->hasFile('image') && $request->file('image')->isValid()) {
            $imagePath = $request->file('image')->store('products', 'public');
        }

        $createdProduct      = false;
        $createdProductColor = false;
        $skipped             = false;

        try {
            DB::transaction(function () use (
                $productName, $colorName, $qualityId, $typeId, $imagePath,
                &$createdProduct, &$createdProductColor, &$skipped
            ) {
                // ── 1. Resolve product (name + quality + type) ──────────────
                $product = Product::where('name', $productName)
                    ->when($qualityId !== null,
                        fn ($q) => $q->where('product_quality_id', $qualityId),
                        fn ($q) => $q->whereNull('product_quality_id'),
                    )
                    ->when($typeId !== null,
                        fn ($q) => $q->where('product_type_id', $typeId),
                        fn ($q) => $q->whereNull('product_type_id'),
                    )
                    ->first();

                if (! $product) {
                    $product = Product::create([
                        'name'               => $productName,
                        'product_quality_id' => $qualityId,
                        'product_type_id'    => $typeId,
                        'unit'               => 'piece',
                        'status'             => 'active',
                    ]);
                    $createdProduct = true;
                }

                // ── 2. Resolve color ────────────────────────────────────────
                $color = Color::firstOrCreate(['name' => $colorName]);

                // ── 3. Create product-color (skip if already exists) ────────
                $exists = ProductColor::where('product_id', $product->id)
                    ->where('color_id', $color->id)
                    ->exists();

                if ($exists) {
                    $skipped = true;
                    return;
                }

                ProductColor::create([
                    'product_id' => $product->id,
                    'color_id'   => $color->id,
                    'image'      => $imagePath,
                ]);
                $createdProductColor = true;
            });
        } catch (\Throwable $e) {
            if ($imagePath) {
                Storage::disk('public')->delete($imagePath);
            }

            return response()->json(['message' => 'Import failed: ' . $e->getMessage()], 500);
        }

        // If skipped, the uploaded image was never used — clean it up.
        if ($skipped && $imagePath) {
            Storage::disk('public')->delete($imagePath);
        }

        return response()->json([
            'data' => [
                'created_product'       => $createdProduct,
                'created_product_color' => $createdProductColor,
                'skipped'               => $skipped,
            ],
        ], 201);
    }
}
