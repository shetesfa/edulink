<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$request = Illuminate\Http\Request::create('/api/meetings/1', 'GET');
$user = App\Models\User::find(2); // teacher
$request->setUserResolver(function () use ($user) { return $user; });

$response = app()->handle($request);
echo "Show Status: " . $response->getStatusCode() . "\n";
// echo $response->getContent();

$request2 = Illuminate\Http\Request::create('/api/meetings/1/token', 'GET');
$request2->setUserResolver(function () use ($user) { return $user; });
$response2 = app()->handle($request2);
echo "Token Status: " . $response2->getStatusCode() . "\n";
// echo $response2->getContent();
