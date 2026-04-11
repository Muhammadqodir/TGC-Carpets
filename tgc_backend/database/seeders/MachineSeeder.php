<?php

namespace Database\Seeders;

use App\Models\Machine;
use Illuminate\Database\Seeder;

class MachineSeeder extends Seeder
{
    public function run(): void
    {
        $machines = [
            ['name' => 'Mashina 1', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 2', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 3', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 4', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 5', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 6', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 7', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 8', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 9', 'model_name' => 'Van de Wiele SRX-200'],
            ['name' => 'Mashina 10', 'model_name' => 'Van de Wiele SRX-200'],
        ];

        foreach ($machines as $machine) {
            Machine::firstOrCreate(['name' => $machine['name']], $machine);
        }
    }
}
