<?php

namespace Database\Seeders;

use App\Models\Machine;
use Illuminate\Database\Seeder;

class MachineSeeder extends Seeder
{
    public function run(): void
    {
        $machines = [
            ['name' => 'Stanok 1', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 2', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 3', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 4', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 5', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 6', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 7', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 8', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 9', 'model_name' => 'Van de Wiele'],
            ['name' => 'Stanok 10', 'model_name' => 'Van de Wiele'],
        ];

        foreach ($machines as $machine) {
            Machine::firstOrCreate(['name' => $machine['name']], $machine);
        }
    }
}
