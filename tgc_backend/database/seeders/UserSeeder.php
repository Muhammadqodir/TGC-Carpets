<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        $users = [
            [
                'name'     => 'Admin User',
                'email'    => 'admin@tgc.com',
                'phone'    => '+998901000001',
                'role'     => User::ROLE_ADMIN,
                'password' => Hash::make('admin123'),
            ],
            [
                'name'     => 'Warehouse Manager',
                'email'    => 'warehouse@tgc.com',
                'phone'    => '+998901000002',
                'role'     => User::ROLE_WAREHOUSE,
                'password' => Hash::make('warehouse123'),
            ],
            [
                'name'     => 'Sales Agent',
                'email'    => 'seller@tgc.com',
                'phone'    => '+998901000003',
                'role'     => User::ROLE_SELLER,
                'password' => Hash::make('seller123'),
            ],
        ];

        foreach ($users as $data) {
            User::updateOrCreate(
                ['email' => $data['email']],
                $data,
            );
        }
    }
}
