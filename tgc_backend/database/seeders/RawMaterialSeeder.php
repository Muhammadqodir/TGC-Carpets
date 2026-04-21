<?php

namespace Database\Seeders;

use App\Models\RawMaterial;
use Illuminate\Database\Seeder;

class RawMaterialSeeder extends Seeder
{
    public function run(): void
    {
        $materials = [
            ['name' => 'PP Ip',        'type' => 'Ip',       'unit' => 'kg'],
            ['name' => 'Polyester Ip', 'type' => 'Ip',       'unit' => 'kg'],
            ['name' => 'Nylon Ip',     'type' => 'Ip',       'unit' => 'kg'],
            ['name' => 'Latex',        'type' => 'Kimyo',    'unit' => 'kg'],
            ['name' => 'Boyoq',        'type' => 'Kimyo',    'unit' => 'kg'],
            ['name' => 'Gilam asosi',  'type' => 'Material', 'unit' => 'sqm'],
            ['name' => 'Qadoqlash',    'type' => 'Material', 'unit' => 'piece'],
        ];

        foreach ($materials as $data) {
            RawMaterial::firstOrCreate(
                ['name' => $data['name'], 'type' => $data['type']],
                ['unit' => $data['unit']]
            );
        }
    }
}
