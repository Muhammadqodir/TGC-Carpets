<?php

namespace Database\Factories;

use App\Models\ProductSize;
use App\Models\ProductType;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProductSize>
 */
class ProductSizeFactory extends Factory
{
    protected $model = ProductSize::class;

    public function definition(): array
    {
        return [
            'length'          => fake()->randomElement([150, 200, 250, 300]),
            'width'           => fake()->randomElement([80, 100, 150, 200]),
            'product_type_id' => ProductType::factory(),
        ];
    }
}
