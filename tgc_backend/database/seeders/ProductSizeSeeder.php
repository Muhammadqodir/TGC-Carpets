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
                ['width' => 100, 'length' => 150],
                ['width' => 100, 'length' => 200],
                ['width' => 100, 'length' => 250],

                ['width' => 150, 'length' => 300],
                ['width' => 150, 'length' => 200],
                ['width' => 150, 'length' => 250],

                ['width' => 175, 'length' => 250],
                ['width' => 175, 'length' => 275],

                ['width' => 180, 'length' => 280],

                ['width' => 200, 'length' => 300],

                ['width' => 250, 'length' => 350],
                ['width' => 250, 'length' => 400],
                ['width' => 250, 'length' => 450],
                ['width' => 250, 'length' => 500],
                ['width' => 250, 'length' => 550],
                ['width' => 250, 'length' => 600],

                ['width' => 300, 'length' => 300],
                ['width' => 300, 'length' => 350],
                ['width' => 300, 'length' => 400],
                ['width' => 300, 'length' => 450],
                ['width' => 300, 'length' => 500],
                ['width' => 300, 'length' => 550],
                ['width' => 300, 'length' => 600],
                ['width' => 300, 'length' => 650],
                ['width' => 300, 'length' => 700],

                ['width' => 350, 'length' => 350],
                ['width' => 350, 'length' => 400],
                ['width' => 350, 'length' => 450],
                ['width' => 350, 'length' => 500],
                ['width' => 350, 'length' => 550],
                ['width' => 350, 'length' => 600],
                ['width' => 350, 'length' => 650],
                ['width' => 350, 'length' => 700],
                ['width' => 350, 'length' => 750],
                ['width' => 350, 'length' => 800],
                ['width' => 350, 'length' => 900],
                ['width' => 350, 'length' => 1000],

                ['width' => 400, 'length' => 400],
                ['width' => 400, 'length' => 450],
                ['width' => 400, 'length' => 500],
                ['width' => 400, 'length' => 550],
                ['width' => 400, 'length' => 600],
                ['width' => 400, 'length' => 650],
                ['width' => 400, 'length' => 700],
                ['width' => 400, 'length' => 800],
                ['width' => 400, 'length' => 900],
                ['width' => 400, 'length' => 1000],

            ],
            'Kovrolin' => [
                ['width' => 80, 'length' => 30000],
                ['width' => 100, 'length' => 30000],
                ['width' => 120, 'length' => 30000],
                ['width' => 150, 'length' => 30000],
                ['width' => 200, 'length' => 30000],
                ['width' => 250, 'length' => 30000],
                ['width' => 300, 'length' => 30000],
                ['width' => 350, 'length' => 30000],
                ['width' => 370, 'length' => 30000],
                ['width' => 400, 'length' => 30000],
            ],
            'Yolak'    => [
                ['width' => 80,  'length' => 3500],
                ['width' => 80,  'length' => 2500],
                ['width' => 100, 'length' => 1800],
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
