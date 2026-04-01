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
                'name'     => 'Muhammadboy',
                'email'    => 'admin@tgc-carpets.uz',
                'phone'    => '+998901000001',
                'role'     => User::ROLE_ADMIN,
                'password' => Hash::make('admin123'),
            ],
            [
                'name'     => 'Akmal',
                'email'    => 'akmal@tgc-carpets.uz',
                'phone'    => '+998901000002',
                'role'     => User::ROLE_WAREHOUSE,
                'password' => Hash::make('warehouse123'),
            ],
            [
                'name'     => 'Sardor',
                'email'    => 'sardor@tgc-carpets.uz',
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
