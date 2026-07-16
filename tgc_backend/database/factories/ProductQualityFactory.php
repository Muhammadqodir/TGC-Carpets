<?php

namespace Database\Factories;

use App\Models\ProductQuality;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProductQuality>
 */
class ProductQualityFactory extends Factory
{
    protected $model = ProductQuality::class;

    public function definition(): array
    {
        return [
            'quality_name' => fake()->unique()->word(),
            'density'      => fake()->numberBetween(1000, 3000),
            'status'       => ProductQuality::STATUS_ACTIVE,
        ];
    }
}
