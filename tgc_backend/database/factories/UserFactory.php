<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name'           => fake()->name(),
            'email'          => fake()->unique()->safeEmail(),
            'phone'          => fake()->numerify('+99890#######'),
            'role'           => [User::ROLE_SALES_MANAGER],
            'password'       => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
        ];
    }

    public function admin(): static
    {
        return $this->state(['role' => [User::ROLE_ADMIN]]);
    }

    public function warehouseManager(): static
    {
        return $this->state(['role' => [User::ROLE_WAREHOUSE_MANAGER]]);
    }

    public function salesManager(): static
    {
        return $this->state(['role' => [User::ROLE_SALES_MANAGER]]);
    }

    public function rawWarehouseManager(): static
    {
        return $this->state(['role' => [User::ROLE_RAW_WAREHOUSE_MANAGER]]);
    }

    public function productManager(): static
    {
        return $this->state(['role' => [User::ROLE_PRODUCT_MANAGER]]);
    }

    public function machineManager(): static
    {
        return $this->state(['role' => [User::ROLE_MACHINE_MANAGER]]);
    }

    public function productionManager(): static
    {
        return $this->state(['role' => [User::ROLE_PRODUCTION_MANAGER]]);
    }

    public function orderManager(): static
    {
        return $this->state(['role' => [User::ROLE_ORDER_MANAGER]]);
    }

    public function labelManager(): static
    {
        return $this->state(['role' => User::ROLE_LABEL_MANAGER]);
    }

    // Legacy methods for backward compatibility
    public function warehouse(): static
    {
        return $this->warehouseManager();
    }

    public function seller(): static
    {
        return $this->salesManager();
    }
}
