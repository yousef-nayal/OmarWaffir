<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreReportRequest;
use App\Http\Resources\ReportResource;
use App\Models\ActivityLog;
use App\Models\Report;
use App\Services\ActivityLogger;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function __construct(private readonly ActivityLogger $activity)
    {
    }

    /** GET /reports - admin. */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'user_id' => ['nullable', 'integer', 'exists:users,id'],
            'product_id' => ['nullable', 'integer', 'exists:products,id'],
            'store_id' => ['nullable', 'integer', 'exists:stores,id'],
            'sector_id' => ['nullable', 'integer', 'exists:sectors,id'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'type' => ['nullable', 'string', 'max:255'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Report::query()
            ->with(['user', 'price.product', 'price.unit', 'price.store.location.sector']);

        if (! empty($filters['search'])) {
            $search = '%'.$filters['search'].'%';
            $query->where(function ($q) use ($search) {
                $q->whereHas('user', fn ($u) => $u->where('name', 'ILIKE', $search))
                    ->orWhereHas('price.product', fn ($p) => $p->where('name', 'ILIKE', $search))
                    ->orWhereHas('price.store', fn ($s) => $s->where('name', 'ILIKE', $search));
            });
        }

        if (! empty($filters['user_id'])) {
            $query->where('user_id', (int) $filters['user_id']);
        }

        if (! empty($filters['type'])) {
            $query->where('type', $filters['type']);
        }

        if (! empty($filters['product_id'])) {
            $query->whereHas('price', fn ($q) => $q->where('product_id', (int) $filters['product_id']));
        }

        if (! empty($filters['store_id'])) {
            $query->whereHas('price', fn ($q) => $q->where('store_id', (int) $filters['store_id']));
        }

        if (! empty($filters['location_id'])) {
            $query->whereHas('price.store', fn ($q) => $q->where('location_id', (int) $filters['location_id']));
        }

        if (! empty($filters['sector_id'])) {
            $query->whereHas('price.store.location', fn ($q) => $q->where('sector_id', (int) $filters['sector_id']));
        }

        $paginator = $query->orderByDesc('created_at')
            ->paginate((int) ($filters['per_page'] ?? 20))
            ->withQueryString();

        return ApiResponse::paginated($paginator, ReportResource::class);
    }

    /** POST /reports - any authenticated user. */
    public function store(StoreReportRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();

        $report = Report::create([
            'user_id' => $user->id,
            'price_id' => (int) $data['price_id'],
            'type' => $data['type'],
            // The database CHECK only allows a description for "wrong info".
            'description' => Report::requiresDescription($data['type'])
                ? ($data['description'] ?? null)
                : null,
        ]);

        $report->load(['user', 'price.product', 'price.unit', 'price.store.location.sector']);

        $this->activity->log(
            ActivityLog::TYPE_REPORT,
            Msg::activityReportAdded($user->name, $report->price?->product?->name ?? ''),
            $user->id,
            $report,
        );

        return ApiResponse::created(new ReportResource($report), Msg::REPORT_SAVED);
    }

    /** DELETE /reports/{report} - admin. */
    public function destroy(Report $report): JsonResponse
    {
        $report->delete();

        return ApiResponse::action(Msg::DELETED);
    }
}
