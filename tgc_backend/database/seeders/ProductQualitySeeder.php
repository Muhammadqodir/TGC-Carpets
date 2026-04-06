<?php

namespace Database\Seeders;

use App\Models\ProductQuality;
use Illuminate\Database\Seeder;

class ProductQualitySeeder extends Seeder
{
    public function run(): void
    {
        $qualities = [
            'ASL PODSHOX GILAMI',
            'ANFAU',
            'RONALDO',
            'TOYOTTA LEXUS',
        ];

        foreach ($qualities as $name) {
            ProductQuality::firstOrCreate(['quality_name' => $name]);
        }
    }
}
