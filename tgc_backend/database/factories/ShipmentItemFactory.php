<?php

namespace Database\Factories;

use App\Models\OrderItem;
use App\Models\ProductVariant;
use App\Models\Shipment;
use App\Models\ShipmentItem;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ShipmentItem>
 */
class ShipmentItemFactory extends Factory
{
    protected $model = ShipmentItem::class;

    public function definition(): array
    {
        return [
            'shipment_id'        => Shipment::factory(),
            'order_item_id'      => OrderItem::factory(),
            'product_variant_id' => ProductVariant::factory(),
            'quantity'           => fake()->numberBetween(1, 20),
            'price'              => fake()->randomFloat(2, 1, 100),
        ];
    }
}
