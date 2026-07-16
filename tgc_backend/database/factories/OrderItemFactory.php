<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductVariant;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<OrderItem>
 */
class OrderItemFactory extends Factory
{
    protected $model = OrderItem::class;

    public function definition(): array
    {
        return [
            'order_id'           => Order::factory(),
            'product_variant_id' => ProductVariant::factory(),
            'quantity'           => fake()->numberBetween(1, 50),
        ];
    }
}
