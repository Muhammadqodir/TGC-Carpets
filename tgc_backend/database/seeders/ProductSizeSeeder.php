<?php

namespace Database\Seeders;

use App\Models\ProductSize;
use App\Models\ProductType;
use Illuminate\Database\Seeder;

class ProductSizeSeeder extends Seeder
{
    public function run(): void
    {
        // 3 standard sizes per product type (length x width in cm)
        $sizes = [
            'Gilam'    => [
                ['length' => 250, 'width' => 200],
                ['length' => 350, 'width' => 250],
                ['length' => 350, 'width' => 300],
            ],
            'Kovrolin' => [
                ['length' => 250, 'width' => 200],
                ['length' => 350, 'width' => 250],
                ['length' => 350, 'width' => 300],
            ],
            'Yolak'    => [
                ['length' => 80,  'width' => 3500],
                ['length' => 80,  'width' => 2500],
                ['length' => 100, 'width' => 1800],
            ],
        ];

        foreach ($sizes as $typeName => $typeSizes) {
            $type = ProductType::where('type', $typeName)->first();

            if (! $type) {
                continue;
            }

            foreach ($typeSizes as $size) {
                ProductSize::firstOrCreate(
                    [
                        'length'          => $size['length'],
                        'width'           => $size['width'],
                        'product_type_id' => $type->id,
                    ]
                );
            }
        }
    }
}
