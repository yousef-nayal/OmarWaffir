<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Throwable;

class HealthController extends Controller
{
    /** GET /health - checks Laravel and the PostgreSQL connection. */
    public function __invoke(): JsonResponse
    {
        $database = 'down';
        $driver = config('database.default');
        $version = null;

        try {
            $version = DB::selectOne('select version() as version')->version ?? null;
            $database = 'up';
        } catch (Throwable $e) {
            report($e);
        }

        return ApiResponse::ok([
            'status' => $database === 'up' ? 'ok' : 'degraded',
            'app' => config('app.name'),
            'environment' => config('app.env'),
            'database_driver' => $driver,
            'database' => $database,
            'database_version' => $version,
            'time' => now()->utc()->toIso8601ZuluString(),
        ], 'Waffir API');
    }
}
