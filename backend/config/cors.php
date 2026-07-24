<?php

$userOrigins = explode(',', env('CORS_ALLOWED_ORIGINS', ''));
$defaultOrigins = ['http://localhost:3000', 'http://localhost:5173', 'https://edulink-blond.vercel.app'];

return [
    'paths'                    => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods'          => ['*'],
    'allowed_origins'          => array_merge($defaultOrigins, $userOrigins),
    'allowed_origins_patterns' => [],
    'allowed_headers'          => ['*'],
    'exposed_headers'          => [],
    'max_age'                  => 0,
    'supports_credentials'     => true,
];
