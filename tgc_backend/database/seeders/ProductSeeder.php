<?php

namespace Database\Seeders;

use App\Models\Color;
use App\Models\Product;
use App\Models\ProductColor;
use App\Models\ProductQuality;
use App\Models\ProductType;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;

class ProductSeeder extends Seeder
{
    public function run(): void
    {
        $path = database_path('seeders/products.json');

        if (! File::exists($path)) {
            $this->command->warn("products.json not found at {$path}. Skipping.");
            return;
        }

        $items = json_decode(File::get($path), true);

        if (empty($items)) {
            $this->command->warn('products.json is empty. Skipping.');
            return;
        }

        // Cache lookups to avoid N+1 queries
        $typeCache    = [];
        $qualityCache = [];
        $colorCache   = [];
        $productCache = []; // key: "name|typeId|qualityId"
        $productColors = 0;
        $products      = 0;

        foreach ($items as $item) {
            $typeName    = $item['type'] ?? null;
            $qualityName = $item['quality'] ?? null;
            $name        = trim($item['name'] ?? '');
            $colorName   = trim($item['color'] ?? '');
            $image       = $item['image'] ?? null;

            if ($name === '' || $colorName === '') {
                continue;
            }

            // Resolve ProductType
            $typeId = null;
            if ($typeName) {
                if (! isset($typeCache[$typeName])) {
                    $typeCache[$typeName] = ProductType::firstOrCreate(['type' => $typeName])->id;
                }
                $typeId = $typeCache[$typeName];
            }

            // Resolve ProductQuality
            $qualityId = null;
            if ($qualityName) {
                if (! isset($qualityCache[$qualityName])) {
                    $qualityCache[$qualityName] = ProductQuality::firstOrCreate(['quality_name' => $qualityName])->id;
                }
                $qualityId = $qualityCache[$qualityName];
            }

            // Resolve Color
            if (! isset($colorCache[$colorName])) {
                $colorCache[$colorName] = Color::firstOrCreate(['name' => $colorName])->id;
            }
            $colorId = $colorCache[$colorName];

            // Resolve Product (unique by name + type + quality)
            $productKey = "{$name}|{$typeId}|{$qualityId}";
            if (! isset($productCache[$productKey])) {
                $product = Product::firstOrCreate(
                    [
                        'name'            => $name,
                        'product_type_id' => $typeId,
                        'product_quality_id' => $qualityId,
                    ],
                    [
                        'uuid'   => (string) Str::uuid(),
                        'unit'   => 'm2',
                        'status' => 'active',
                    ]
                );
                $productCache[$productKey] = $product->id;
                $products++;
            }
            $productId = $productCache[$productKey];

            // Create ProductColor (unique per product + color)
            ProductColor::firstOrCreate(
                [
                    'product_id' => $productId,
                    'color_id'   => $colorId,
                ],
                [
                    'image' => $image,
                ]
            );
            $productColors++;
        }

        $this->command->info("Seeded {$products} products, {$productColors} product-colors from products.json.");
    }
}
