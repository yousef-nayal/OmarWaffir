<?php

namespace App\Http\Controllers\Api\V1\Admin;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use App\Models\Price;
use App\Models\Product;
use App\Models\Report;
use App\Models\Store;
use App\Models\User;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

/**
 * Every number here is a real aggregate over PostgreSQL. Growth compares the
 * current N-day window with the immediately preceding one.
 */
class DashboardController extends Controller
{
    /** GET /admin/dashboard-stats */
    public function stats(): JsonResponse
    {
        $days = (int) config('waffir.dashboard.growth_period_days', 30);
        $now = Carbon::now();
        $currentStart = $now->copy()->subDays($days);
        $previousStart = $now->copy()->subDays($days * 2);

        return ApiResponse::ok([
            'totalUsers' => User::count(),
            'totalProducts' => Product::count(),
            'totalStores' => Store::count(),
            'totalPrices' => Price::count(),
            'totalReports' => Report::count(),
            'usersGrowth' => $this->growth(User::query(), $currentStart, $previousStart),
            'productsGrowth' => $this->growth(Product::query(), $currentStart, $previousStart),
            'storesGrowth' => $this->growth(Store::query(), $currentStart, $previousStart),
            'pricesGrowth' => $this->growth(Price::query(), $currentStart, $previousStart),
            'reportsGrowth' => $this->growth(Report::query(), $currentStart, $previousStart),
            'period_days' => $days,
        ], Msg::FETCHED);
    }

    /** GET /admin/recent-activity */
    public function recentActivity(): JsonResponse
    {
        $limit = (int) config('waffir.dashboard.recent_activity_limit', 20);

        $items = ActivityLog::query()
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get()
            ->map(fn (ActivityLog $log): array => [
                'type' => $log->type,
                'text' => $log->text,
                'time' => $this->humanTime($log->created_at),
                'color' => $log->color(),
                'created_at' => $log->created_at?->utc()->toIso8601ZuluString(),
            ])
            ->all();

        return ApiResponse::ok($items, Msg::FETCHED);
    }

    /**
     * Percentage change between the current and the previous window.
     * A period that starts from zero is reported as +100% when it grew,
     * never as a division by zero.
     */
    private function growth(Builder $query, Carbon $currentStart, Carbon $previousStart): float
    {
        $current = (clone $query)->where('created_at', '>=', $currentStart)->count();
        $previous = (clone $query)
            ->where('created_at', '>=', $previousStart)
            ->where('created_at', '<', $currentStart)
            ->count();

        if ($previous === 0) {
            return $current > 0 ? 100.0 : 0.0;
        }

        return round((($current - $previous) / $previous) * 100, 2);
    }

    private function humanTime(?Carbon $at): string
    {
        return $at?->locale('ar')->diffForHumans() ?? '';
    }
}
