<?php

namespace Database\Seeders;

use App\Models\ProductType;
use Illuminate\Database\Seeder;

class ProductTypeSeeder extends Seeder
{
    public function run(): void
    {
        $types = ['Gilam', 'Kovrolin', 'Yolak', 'Porta'];

        foreach ($types as $type) {
            ProductType::firstOrCreate(['type' => $type]);
        }
    }
}
