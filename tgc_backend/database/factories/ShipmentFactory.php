<?php

namespace Database\Factories;

use App\Models\Client;
use App\Models\Shipment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Shipment>
 */
class ShipmentFactory extends Factory
{
    protected $model = Shipment::class;

    public function definition(): array
    {
        return [
            'client_id'         => Client::factory(),
            'user_id'           => User::factory(),
            'shipment_datetime' => now(),
        ];
    }
}
