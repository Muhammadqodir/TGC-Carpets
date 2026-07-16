<?php

namespace Database\Factories;

use App\Models\Product;
use App\Models\ProductQuality;
use App\Models\ProductType;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Product>
 */
class ProductFactory extends Factory
{
    protected $model = Product::class;

    public function definition(): array
    {
        return [
            'name'               => fake()->unique()->words(2, true),
            'product_type_id'    => ProductType::factory(),
            'product_quality_id' => ProductQuality::factory(),
            'unit'               => Product::UNIT_M2,
            'status'             => Product::STATUS_ACTIVE,
        ];
    }

    public function piece(): static
    {
        return $this->state(['unit' => Product::UNIT_PIECE]);
    }
}
