<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Role;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            ['id' => 1, 'name' => 'guest'],
            ['id' => 2, 'name' => 'student'],
            ['id' => 3, 'name' => 'teacher'],
            ['id' => 4, 'name' => 'school_admin'],
            ['id' => 5, 'name' => 'super_admin'],
        ];

        foreach ($roles as $role) {
            Role::firstOrCreate(['id' => $role['id']], $role);
        }
    }
}
