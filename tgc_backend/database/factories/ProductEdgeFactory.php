<?php

namespace Database\Factories;

use App\Models\ProductEdge;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProductEdge>
 */
class ProductEdgeFactory extends Factory
{
    protected $model = ProductEdge::class;

    public function definition(): array
    {
        return [
            'code'  => fake()->unique()->lexify('?'),
            'title' => fake()->word(),
        ];
    }
}
