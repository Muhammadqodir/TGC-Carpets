<?php

namespace Database\Seeders;

use App\Models\Product;
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
        $count        = 0;

        foreach ($items as $item) {
            $typeName    = $item['type'] ?? null;
            $qualityName = $item['quality'] ?? null;
            $name        = trim($item['name'] ?? '');
            $color       = trim($item['color'] ?? '');
            $image       = $item['image'] ?? null;

            if ($name === '' || $color === '') {
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

            $sku = 'TGC-' . strtoupper(Str::slug($name, '-')) . '-' . strtoupper(Str::slug($color, '-'));
            // Append type suffix to stay unique when same name+color spans multiple types
            if ($typeId) {
                $sku .= '-T' . $typeId;
            }

            Product::firstOrCreate(
                [
                    'name'            => $name,
                    'color'           => $color,
                    'product_type_id' => $typeId,
                ],
                [
                    'uuid'               => (string) Str::uuid(),
                    'sku_code'           => $sku,
                    'product_quality_id' => $qualityId,
                    'unit'               => 'piece',
                    'status'             => 'active',
                    'image'              => $image,
                ]
            );

            $count++;
        }

        $this->command->info("Seeded {$count} products from products.json.");
    }
}
