<?php

use App\Http\Controllers\Api\V1\Admin\AdminUserController;
use App\Http\Controllers\Api\V1\Admin\DeletionImpactController;
use App\Http\Controllers\Api\V1\Admin\DashboardController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CatalogController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\OfficialPriceController;
use App\Http\Controllers\Api\V1\PriceController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\StoreController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Waffir API v1   (every route below is prefixed with /api/v1)
|--------------------------------------------------------------------------
|
| Authorisation is enforced here and in middleware, never in the Flutter
| navigation stack:
|   auth:sanctum + active  -> any signed-in, non-blocked account
|   role:1                 -> admin or super admin
|   role:2                 -> super admin only
*/

Route::get('health', HealthController::class);

// ── Authentication ─────────────────────────────────────────────────────────
Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('admin/login', [AuthController::class, 'adminLogin'])->middleware('throttle:10,1');
    Route::post('verify-otp', [AuthController::class, 'verifyOtp'])->middleware('throttle:15,1');
    Route::post('resend-otp', [AuthController::class, 'resendOtp'])->middleware('throttle:6,1');
    Route::post('forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:6,1');
    Route::put('reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:10,1');
    Route::post('refresh', [AuthController::class, 'refresh'])->middleware('throttle:30,1');

    Route::middleware(['auth:sanctum', 'active'])->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        Route::put('profile', [AuthController::class, 'updateProfile']);
        Route::post('change-password/request-otp', [AuthController::class, 'requestChangePasswordOtp'])
            ->middleware('throttle:6,1');
        Route::put('change-password', [AuthController::class, 'changePassword']);
    });
});

// ── Public reference data (needed by the registration / store forms) ───────
Route::get('sectors', [CatalogController::class, 'sectors']);
Route::get('locations', [CatalogController::class, 'locations']);
Route::get('units', [CatalogController::class, 'units']);
Route::get('brands', [CatalogController::class, 'brands']);

// ── Public catalogue reads ────────────────────────────────────────────────
Route::get('products', [ProductController::class, 'index']);
Route::get('products/categories', [ProductController::class, 'categories']);
Route::get('products/{product}', [ProductController::class, 'show']);
Route::get('products/{product}/prices', [ProductController::class, 'prices']);
Route::get('stores', [StoreController::class, 'index']);
Route::get('stores/{store}', [StoreController::class, 'show']);
Route::get('official-prices', [OfficialPriceController::class, 'index']);
Route::get('official-prices/{officialPrice}/history', [OfficialPriceController::class, 'history']);

// ── Authenticated user actions ────────────────────────────────────────────
Route::middleware(['auth:sanctum', 'active'])->group(function () {
    Route::post('prices', [PriceController::class, 'store'])->middleware('throttle:60,1');
    Route::post('prices/{price}/vote', [PriceController::class, 'vote'])->middleware('throttle:120,1');
    Route::post('reports', [ReportController::class, 'store'])->middleware('throttle:30,1');
    Route::post('stores', [StoreController::class, 'store'])->middleware('throttle:20,1');

    Route::get('notifications', [NotificationController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::patch('notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::patch('notifications/{id}/read', [NotificationController::class, 'markRead']);
});

// ── Administrator (role >= 1) ─────────────────────────────────────────────
Route::middleware(['auth:sanctum', 'active', 'role:1'])->group(function () {
    // Review queues
    Route::get('prices', [PriceController::class, 'index']);
    Route::delete('prices/{price}', [PriceController::class, 'destroy']);
    Route::get('reports', [ReportController::class, 'index']);
    Route::delete('reports/{report}', [ReportController::class, 'destroy']);

    // Catalogue management
    Route::post('products', [ProductController::class, 'store']);
    Route::put('products/{product}', [ProductController::class, 'update']);
    Route::delete('products/{product}', [ProductController::class, 'destroy']);

    Route::put('stores/{store}', [StoreController::class, 'update']);
    Route::patch('stores/{store}/verify', [StoreController::class, 'verify']);
    Route::delete('stores/{store}', [StoreController::class, 'destroy']);

    Route::post('official-prices', [OfficialPriceController::class, 'store']);
    Route::put('official-prices/{officialPrice}', [OfficialPriceController::class, 'update']);
    Route::delete('official-prices/{officialPrice}', [OfficialPriceController::class, 'destroy']);

    Route::post('sectors', [CatalogController::class, 'storeSector']);
    Route::put('sectors/{sector}', [CatalogController::class, 'updateSector']);
    Route::delete('sectors/{sector}', [CatalogController::class, 'destroySector']);

    Route::post('locations', [CatalogController::class, 'storeLocation']);
    Route::put('locations/{location}', [CatalogController::class, 'updateLocation']);
    Route::delete('locations/{location}', [CatalogController::class, 'destroyLocation']);

    Route::post('units', [CatalogController::class, 'storeUnit']);
    Route::put('units/{unit}', [CatalogController::class, 'updateUnit']);
    Route::delete('units/{unit}', [CatalogController::class, 'destroyUnit']);

    Route::post('brands', [CatalogController::class, 'storeBrand']);
    Route::put('brands/{brand}', [CatalogController::class, 'updateBrand']);
    Route::delete('brands/{brand}', [CatalogController::class, 'destroyBrand']);

    // Users and dashboard
    Route::get('admin/users', [AdminUserController::class, 'index']);
    Route::post('admin/users', [AdminUserController::class, 'store']);
    Route::put('admin/users/{user}', [AdminUserController::class, 'update']);
    Route::delete('admin/users/{user}', [AdminUserController::class, 'destroy']);
    Route::patch('admin/users/{user}/block', [AdminUserController::class, 'block']);
    Route::patch('admin/users/{user}/unblock', [AdminUserController::class, 'unblock']);

    // What a delete would take with it, for the confirmation dialog.
    Route::get('admin/deletion-impact/{type}/{id}', [DeletionImpactController::class, 'show'])
        ->whereNumber('id');

    Route::get('admin/dashboard-stats', [DashboardController::class, 'stats']);
    Route::get('admin/recent-activity', [DashboardController::class, 'recentActivity']);
});

// ── Super administrator (role 2) ──────────────────────────────────────────
Route::middleware(['auth:sanctum', 'active', 'role:2'])->group(function () {
    Route::patch('admin/users/{user}/role', [AdminUserController::class, 'setRole']);
});
