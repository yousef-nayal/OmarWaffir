<?php

/**
 * Generates docs/waffir.postman_collection.json from the real Laravel route
 * table, so the collection can never drift from the routes that exist.
 *
 *   php scripts/generate-postman.php
 *
 * Sample bodies for the write endpoints are listed in BODIES below; anything
 * not listed gets an empty JSON body.
 */

require __DIR__.'/../vendor/autoload.php';

$app = require_once __DIR__.'/../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

/** Sample request bodies, keyed by "METHOD uri". */
const BODIES = [
    'POST api/v1/auth/register' => [
        'name' => 'مستخدم تجريبي',
        'phone_number' => '0991112233',
        'password' => 'Password123!',
        'password_confirmation' => 'Password123!',
        'location_id' => '18',
    ],
    'POST api/v1/auth/verify-otp' => ['phone_number' => '0991112233', 'code' => '123456'],
    'POST api/v1/auth/resend-otp' => ['phone_number' => '0991112233'],
    'POST api/v1/auth/login' => ['phone_number' => '0990000001', 'password' => 'Password123!'],
    'POST api/v1/auth/admin/login' => ['username' => 'admin@waffir.local', 'password' => 'Password123!'],
    'POST api/v1/auth/refresh' => ['refresh_token' => '{{refresh_token}}'],
    'POST api/v1/auth/forgot-password' => ['phone_number' => '0990000001'],
    'PUT api/v1/auth/reset-password' => [
        'phone_number' => '0990000001',
        'code' => '123456',
        'new_password' => 'Password123!',
        'new_password_confirmation' => 'Password123!',
    ],
    'PUT api/v1/auth/change-password' => [
        'code' => '123456',
        'new_password' => 'Password123!',
        'new_password_confirmation' => 'Password123!',
    ],
    'PUT api/v1/auth/profile' => ['name' => 'اسم جديد', 'location_id' => '18'],
    'POST api/v1/products' => ['name' => 'منتج جديد', 'category' => 'حبوب ومطاحن'],
    'PUT api/v1/products/{product}' => ['name' => 'اسم معدّل', 'category' => 'حبوب ومطاحن'],
    'POST api/v1/stores' => ['location_id' => '18', 'name' => 'متجر جديد', 'address' => 'شارع رئيسي'],
    'PUT api/v1/stores/{store}' => ['name' => 'متجر معدّل', 'address' => 'شارع آخر', 'location_id' => '18'],
    'PATCH api/v1/stores/{store}/verify' => ['is_verified' => true],
    'POST api/v1/prices' => [
        'product_id' => '1', 'store_id' => '1', 'unit_id' => '1',
        'brand_id' => '1', 'amount' => 1, 'price' => 120,
    ],
    'POST api/v1/prices/{price}/vote' => ['is_up' => true],
    'POST api/v1/reports' => ['price_id' => '1', 'type' => 'سعر مبالغ فيه'],
    'POST api/v1/official-prices' => ['product_id' => '1', 'unit_id' => '1', 'amount' => 1, 'price' => 110],
    'PUT api/v1/official-prices/{officialPrice}' => ['product_id' => '1', 'unit_id' => '1', 'amount' => 1, 'price' => 125],
    'POST api/v1/sectors' => ['name' => 'كتلة جديدة', 'description' => 'وصف'],
    'PUT api/v1/sectors/{sector}' => ['name' => 'كتلة معدّلة', 'description' => 'وصف'],
    'POST api/v1/locations' => ['sector_id' => '1', 'district' => 'حي جديد'],
    'PUT api/v1/locations/{location}' => ['sector_id' => '1', 'district' => 'حي معدّل'],
    'POST api/v1/units' => ['name' => 'وحدة جديدة'],
    'PUT api/v1/units/{unit}' => ['name' => 'وحدة معدّلة'],
    'POST api/v1/brands' => ['name' => 'علامة جديدة'],
    'PUT api/v1/brands/{brand}' => ['name' => 'علامة معدّلة'],
    'POST api/v1/admin/users' => [
        'name' => 'مستخدم من الإدارة', 'phone_number' => '0995550000',
        'password' => 'Password123!', 'location_id' => '18', 'role' => 0,
    ],
    'PUT api/v1/admin/users/{user}' => ['name' => 'اسم معدّل'],
    'PATCH api/v1/admin/users/{user}/role' => ['role' => 1],
];

/** Query parameters worth pre-filling (disabled by default in Postman). */
const QUERIES = [
    'GET api/v1/products' => ['search', 'category', 'location_id', 'page', 'per_page'],
    'GET api/v1/products/{product}' => ['location_id'],
    'GET api/v1/products/{product}/prices' => ['location_id'],
    'GET api/v1/stores' => ['search', 'sector_id', 'location_id', 'is_verified', 'page', 'per_page'],
    'GET api/v1/prices' => ['search', 'user_id', 'product_id', 'store_id', 'sector_id', 'location_id', 'brand_id', 'from', 'to', 'page', 'per_page'],
    'GET api/v1/reports' => ['search', 'user_id', 'product_id', 'store_id', 'sector_id', 'location_id', 'type', 'page', 'per_page'],
    'GET api/v1/official-prices' => ['search', 'product_id', 'page', 'per_page'],
    'GET api/v1/locations' => ['search', 'sector_id'],
    'GET api/v1/admin/users' => ['search', 'status', 'sector_id', 'location_id', 'role', 'page', 'per_page'],
    'GET api/v1/notifications' => ['unread', 'page', 'per_page'],
];

function folderFor(string $uri): string
{
    return match (true) {
        str_contains($uri, 'auth/') => 'Auth',
        str_contains($uri, 'admin/') => 'Admin',
        str_contains($uri, 'official-prices') => 'Official prices',
        str_contains($uri, 'notifications') => 'Notifications',
        str_contains($uri, 'products') => 'Products',
        str_contains($uri, 'stores') => 'Stores',
        str_contains($uri, 'prices') => 'Prices',
        str_contains($uri, 'reports') => 'Reports',
        str_contains($uri, 'health') => 'Health',
        default => 'Catalog',
    };
}

$folders = [];

foreach (Illuminate\Support\Facades\Route::getRoutes() as $route) {
    $uri = $route->uri();

    if (! str_starts_with($uri, 'api/v1')) {
        continue;
    }

    foreach ($route->methods() as $method) {
        if (in_array($method, ['HEAD', 'OPTIONS'], true)) {
            continue;
        }

        $key = $method.' '.$uri;
        $middleware = $route->gatherMiddleware();
        $needsAuth = in_array('auth:sanctum', $middleware, true);

        $role = null;
        foreach ($middleware as $m) {
            if (str_starts_with($m, 'role:')) {
                $role = (int) substr($m, 5);
            }
        }

        $path = explode('/', str_replace('{', ':', str_replace('}', '', $uri)));

        $request = [
            'method' => $method,
            'header' => [
                ['key' => 'Accept', 'value' => 'application/json'],
                ['key' => 'Accept-Language', 'value' => 'ar'],
            ],
            'url' => [
                'raw' => '{{base_url}}/'.$uri,
                'host' => ['{{base_url}}'],
                'path' => $path,
            ],
        ];

        if (isset(QUERIES[$key])) {
            $request['url']['query'] = array_map(
                static fn (string $q): array => ['key' => $q, 'value' => '', 'disabled' => true],
                QUERIES[$key],
            );
        }

        if (isset(BODIES[$key])) {
            $request['header'][] = ['key' => 'Content-Type', 'value' => 'application/json'];
            $request['body'] = [
                'mode' => 'raw',
                'raw' => json_encode(BODIES[$key], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE),
                'options' => ['raw' => ['language' => 'json']],
            ];
        }

        if (! $needsAuth) {
            $request['auth'] = ['type' => 'noauth'];
        }

        $description = $needsAuth
            ? ($role === null ? 'Requires a signed-in user.' : "Requires role >= {$role}.")
            : 'Public.';

        $name = $method.' /'.substr($uri, strlen('api/v1/'));

        $item = [
            'name' => $name,
            'request' => $request + ['description' => $description],
            'response' => [],
        ];

        // Capture the tokens automatically on the endpoints that mint them.
        if (in_array($key, [
            'POST api/v1/auth/login',
            'POST api/v1/auth/admin/login',
            'POST api/v1/auth/verify-otp',
            'POST api/v1/auth/refresh',
        ], true)) {
            $item['event'] = [[
                'listen' => 'test',
                'script' => [
                    'type' => 'text/javascript',
                    'exec' => [
                        'const body = pm.response.json();',
                        'if (body && body.data && body.data.access_token) {',
                        "    pm.collectionVariables.set('access_token', body.data.access_token);",
                        "    pm.collectionVariables.set('refresh_token', body.data.refresh_token);",
                        '}',
                    ],
                ],
            ]];
        }

        $folders[folderFor($uri)][] = $item;
    }
}

ksort($folders);

foreach ($folders as &$items) {
    usort($items, static fn (array $a, array $b): int => strcmp($a['name'], $b['name']));
}
unset($items);

$collection = [
    'info' => [
        'name' => 'Waffir API v1',
        'description' => "Generated from the Laravel route table by scripts/generate-postman.php.\n\n"
            ."Set {{base_url}} to your backend, then run \"POST /auth/login\" - the token variables\n"
            .'fill themselves in from the response.',
        'schema' => 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    ],
    'auth' => [
        'type' => 'bearer',
        'bearer' => [['key' => 'token', 'value' => '{{access_token}}', 'type' => 'string']],
    ],
    'variable' => [
        ['key' => 'base_url', 'value' => 'http://127.0.0.1:8000/api/v1'],
        ['key' => 'access_token', 'value' => ''],
        ['key' => 'refresh_token', 'value' => ''],
    ],
    'item' => array_map(
        static fn (string $name, array $items): array => ['name' => $name, 'item' => $items],
        array_keys($folders),
        array_values($folders),
    ),
];

$target = __DIR__.'/../../docs/waffir.postman_collection.json';

file_put_contents(
    $target,
    json_encode($collection, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE)."\n",
);

$count = array_sum(array_map('count', $folders));
echo "Wrote {$target}\n{$count} requests in ".count($folders)." folders\n";
