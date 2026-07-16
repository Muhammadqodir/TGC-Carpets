<?php

namespace Database\Factories;

use App\Models\Client;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    protected $model = Order::class;

    public function definition(): array
    {
        return [
            'user_id'    => User::factory(),
            'client_id'  => Client::factory(),
            'status'     => Order::STATUS_PENDING,
            'order_date' => now()->toDateString(),
        ];
    }
}
