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
    public function store(Request $request): JsonResponse
    {
        $request->validate([
            'product_quality_id'  => ['nullable', 'integer', 'exists:product_qualities,id'],
            'product_type_id'     => ['nullable', 'integer', 'exists:product_types,id'],
            'items'               => ['required', 'array', 'min:1', 'max:500'],
            'items.*.name'        => ['required', 'string', 'max:255'],
            'items.*.color'       => ['required', 'string', 'max:100'],
            'items.*.image'       => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ]);

        $qualityId = $request->input('product_quality_id');
        $typeId    = $request->input('product_type_id');
        $items     = $request->input('items', []);

        // Upload images before the transaction — filesystem ops cannot be rolled back.
        // Track every stored path so we can clean up on DB failure.
        $storedImages = [];
        foreach ($request->file('items', []) as $index => $fileGroup) {
            if (isset($fileGroup['image'])) {
                $storedImages[$index] = $fileGroup['image']->store('products', 'public');
            }
        }

        $createdProducts      = 0;
        $createdColors        = 0;
        $createdProductColors = 0;
        $skipped              = 0;

        try {
            DB::transaction(function () use (
                $items, $qualityId, $typeId, $storedImages,
                &$createdProducts, &$createdColors, &$createdProductColors, &$skipped
            ) {
                // Load all colors once into a case-insensitive map to avoid per-row queries.
                $colorCache = Color::all()->keyBy(fn ($c) => strtolower($c->name));

                // Cache products resolved during this run so we hit the DB only once per unique name+quality+type.
                $productCache = [];

                foreach ($items as $index => $item) {
                    $productName = trim($item['name']);
                    $colorName   = trim($item['color']);
                    $imagePath   = $storedImages[$index] ?? null;

                    // ── 1. Resolve product ──────────────────────────────────────
                    $productKey = strtolower($productName)
                        . '|' . ($qualityId ?? 'null')
                        . '|' . ($typeId    ?? 'null');

                    if (isset($productCache[$productKey])) {
                        $product = $productCache[$productKey];
                    } else {
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
                            $createdProducts++;
                        }

                        $productCache[$productKey] = $product;
                    }

                    // ── 2. Resolve color ────────────────────────────────────────
                    $colorKey = strtolower($colorName);
                    if (! isset($colorCache[$colorKey])) {
                        $color = Color::create(['name' => $colorName]);
                        $colorCache[$colorKey] = $color;
                        $createdColors++;
                    }
                    $color = $colorCache[$colorKey];

                    // ── 3. Create product-color (skip duplicates) ───────────────
                    $alreadyExists = ProductColor::where('product_id', $product->id)
                        ->where('color_id', $color->id)
                        ->exists();

                    if ($alreadyExists) {
                        // Release the uploaded image — it won't be used.
                        if ($imagePath) {
                            Storage::disk('public')->delete($imagePath);
                        }
                        $skipped++;
                        continue;
                    }

                    ProductColor::create([
                        'product_id' => $product->id,
                        'color_id'   => $color->id,
                        'image'      => $imagePath,
                    ]);
                    $createdProductColors++;
                }
            });
        } catch (\Throwable $e) {
            foreach ($storedImages as $path) {
                Storage::disk('public')->delete($path);
            }

            return response()->json(['message' => 'Import failed: ' . $e->getMessage()], 500);
        }

        return response()->json([
            'data' => [
                'created_products'       => $createdProducts,
                'created_colors'         => $createdColors,
                'created_product_colors' => $createdProductColors,
                'skipped'                => $skipped,
            ],
        ], 201);
    }
}
