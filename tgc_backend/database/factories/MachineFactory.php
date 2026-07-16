<?php

namespace Database\Factories;

use App\Models\Machine;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Machine>
 */
class MachineFactory extends Factory
{
    protected $model = Machine::class;

    public function definition(): array
    {
        return [
            'name'       => 'Loom ' . fake()->unique()->numberBetween(1, 999),
            'model_name' => fake()->word(),
        ];
    }
}
