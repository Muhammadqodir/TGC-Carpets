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
            [
                'name'     => 'Akmal',
                'email'    => 'warehouse@tgc-carpets.uz',
                'phone'    => '+998901000002',
                'role'     => [User::ROLE_WAREHOUSE_MANAGER],
                'password' => Hash::make('warehouse123'),
            ],
            [
                'name'     => 'Sardor',
                'email'    => 'sales@tgc-carpets.uz',
                'phone'    => '+998901000003',
                'role'     => [User::ROLE_SALES_MANAGER],
                'password' => Hash::make('sales123'),
            ],
            [
                'name'     => 'Aziz',
                'email'    => 'raw_warehouse@tgc-carpets.uz',
                'phone'    => '+998901000004',
                'role'     => [User::ROLE_RAW_WAREHOUSE_MANAGER],
                'password' => Hash::make('raw123'),
            ],
            [
                'name'     => 'Javohir',
                'email'    => 'product@tgc-carpets.uz',
                'phone'    => '+998901000005',
                'role'     => [User::ROLE_PRODUCT_MANAGER],
                'password' => Hash::make('product123'),
            ],
            [
                'name'     => 'Otabek',
                'email'    => 'machine@tgc-carpets.uz',
                'phone'    => '+998901000006',
                'role'     => [User::ROLE_MACHINE_MANAGER],
                'password' => Hash::make('machine123'),
            ],
            [
                'name'     => 'Sanjar',
                'email'    => 'production@tgc-carpets.uz',
                'phone'    => '+998901000007',
                'role'     => [User::ROLE_PRODUCTION_MANAGER],
                'password' => Hash::make('production123'),
            ],
            [
                'name'     => 'Jasur',
                'email'    => 'order@tgc-carpets.uz',
                'phone'    => '+998901000008',
                'role'     => [User::ROLE_ORDER_MANAGER],
                'password' => Hash::make('order123'),
            ],
            [
                'name'     => 'Bobur',
                'email'    => 'label@tgc-carpets.uz',
                'phone'    => '+998901000009',
                'role'     => [User::ROLE_LABEL_MANAGER],
                'password' => Hash::make('label123'),
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
