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
                ['length' => 100, 'width' => 150],
                ['length' => 100, 'width' => 200],
                ['length' => 100, 'width' => 250],

                ['length' => 150, 'width' => 300],
                ['length' => 150, 'width' => 200],
                ['length' => 150, 'width' => 250],

                ['length' => 175, 'width' => 250],
                ['length' => 175, 'width' => 275],

                ['length' => 180, 'width' => 280],

                ['length' => 200, 'width' => 300],

                ['length' => 250, 'width' => 350],
                ['length' => 250, 'width' => 400],
                ['length' => 250, 'width' => 450],
                ['length' => 250, 'width' => 500],
                ['length' => 250, 'width' => 550],
                ['length' => 250, 'width' => 600],

                ['length' => 300, 'width' => 300],
                ['length' => 300, 'width' => 350],
                ['length' => 300, 'width' => 400],
                ['length' => 300, 'width' => 450],
                ['length' => 300, 'width' => 500],
                ['length' => 300, 'width' => 550],
                ['length' => 300, 'width' => 600],
                ['length' => 300, 'width' => 650],
                ['length' => 300, 'width' => 700],

                ['length' => 350, 'width' => 350],
                ['length' => 350, 'width' => 400],
                ['length' => 350, 'width' => 450],
                ['length' => 350, 'width' => 500],
                ['length' => 350, 'width' => 550],
                ['length' => 350, 'width' => 600],
                ['length' => 350, 'width' => 650],
                ['length' => 350, 'width' => 700],
                ['length' => 350, 'width' => 750],
                ['length' => 350, 'width' => 800],
                ['length' => 350, 'width' => 900],
                ['length' => 350, 'width' => 1000],

                ['length' => 400, 'width' => 400],
                ['length' => 400, 'width' => 450],
                ['length' => 400, 'width' => 500],
                ['length' => 400, 'width' => 550],
                ['length' => 400, 'width' => 600],
                ['length' => 400, 'width' => 650],
                ['length' => 400, 'width' => 700],
                ['length' => 400, 'width' => 800],
                ['length' => 400, 'width' => 900],
                ['length' => 400, 'width' => 1000],

            ],
            'Kovrolin' => [
                ['length' => 80, 'width' => 30000],
                ['length' => 100, 'width' => 30000],
                ['length' => 120, 'width' => 30000],
                ['length' => 150, 'width' => 30000],
                ['length' => 200, 'width' => 30000],
                ['length' => 250, 'width' => 30000],
                ['length' => 300, 'width' => 30000],
                ['length' => 350, 'width' => 30000],
                ['length' => 370, 'width' => 30000],
                ['length' => 400, 'width' => 30000],
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
