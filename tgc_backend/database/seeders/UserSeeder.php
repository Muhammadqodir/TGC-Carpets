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
                'role'     => [User::ROLE_ADMIN],
                'password' => Hash::make('admin123'),
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
