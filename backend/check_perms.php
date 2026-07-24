<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$user = DB::table('users')->where('id', 2)->first();
$class = DB::table('classes')->where('id', 1)->first(); // Assuming classId 1

echo "User ID: {$user->id}\n";
echo "User Role ID: {$user->role_id}\n";

$role = DB::table('roles')->where('id', $user->role_id)->first();
echo "User Role Name: {$role->name}\n";

echo "Class ID: {$class->id}\n";
echo "Class Teacher ID: {$class->teacher_id}\n";
