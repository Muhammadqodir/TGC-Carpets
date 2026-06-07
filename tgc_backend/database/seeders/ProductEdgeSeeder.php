<?php

namespace Database\Seeders;

use App\Models\ProductEdge;
use Illuminate\Database\Seeder;

class ProductEdgeSeeder extends Seeder
{
    public function run(): void
    {
        $edges = [
            ['code' => 'R', 'title' => 'Tortburchak'],
            ['code' => 'O', 'title' => 'Ovalsimon'],
        ];

        foreach ($edges as $edge) {
            ProductEdge::firstOrCreate(['code' => $edge['code']], ['title' => $edge['title']]);
        }
    }
}
