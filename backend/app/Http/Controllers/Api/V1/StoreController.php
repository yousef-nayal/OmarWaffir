<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\StoreResource;
use App\Models\ActivityLog;
use App\Models\Store;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Services\DeletionImpactService;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StoreController extends Controller
{
    public function __construct(
        private readonly ActivityLogger $activity,
        private readonly DeletionImpactService $impact,
    ) {
    }

    /** GET /stores?search=&sector_id=&location_id=&is_verified=&page=&per_page= */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'sector_id' => ['nullable', 'integer', 'exists:sectors,id'],
            // Name-based sector filter kept for the existing Flutter dropdown.
            'sector' => ['nullable', 'string', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'is_verified' => ['nullable', 'boolean'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Store::query()
            ->with('location.sector')
            ->withCount('prices');

        if (! empty($filters['search'])) {
            $search = '%'.$filters['search'].'%';
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ILIKE', $search)
                    ->orWhere('address', 'ILIKE', $search)
                    ->orWhereHas('location', fn ($l) => $l->where('district', 'ILIKE', $search));
            });
        }

        if (! empty($filters['sector_id'])) {
            $query->whereHas('location', fn ($q) => $q->where('sector_id', (int) $filters['sector_id']));
        }

        if (! empty($filters['sector']) && $filters['sector'] !== 'الكل') {
            $query->whereHas(
                'location.sector',
                fn ($q) => $q->where('name', $filters['sector']),
            );
        }

        if (! empty($filters['location_id'])) {
            $query->where('location_id', (int) $filters['location_id']);
        }

        if ($request->has('is_verified')) {
            $query->where('is_verified', $request->boolean('is_verified'));
        }

        $paginator = $query->orderByDesc('is_verified')
            ->orderBy('name')
            ->paginate((int) ($filters['per_page'] ?? 20))
            ->withQueryString();

        return ApiResponse::paginated($paginator, StoreResource::class);
    }

    /** GET /stores/{store} */
    public function show(Store $store): JsonResponse
    {
        $store->load('location.sector')->loadCount('prices');

        return ApiResponse::ok(new StoreResource($store), Msg::FETCHED);
    }

    /**
     * POST /stores
     *
     * A store submitted by a normal user is always unverified. An admin may
     * ask for a verified store explicitly.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'location_id' => ['required', 'integer', 'exists:locations,id'],
            'name' => ['required', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'is_verified' => ['nullable', 'boolean'],
        ]);

        $user = $request->user();
        $isAdmin = $user !== null && $user->isAdmin();

        $store = Store::create([
            'location_id' => (int) $data['location_id'],
            'name' => $data['name'],
            'address' => $data['address'],
            'is_verified' => $isAdmin ? (bool) ($data['is_verified'] ?? false) : false,
            'submitted_by_user_id' => $user?->id,
        ]);

        $this->activity->log(
            ActivityLog::TYPE_STORE,
            Msg::activityStoreSubmitted($user?->name ?? '', $store->name),
            $user?->id,
            $store,
        );

        $store->load('location.sector')->loadCount('prices');

        return ApiResponse::created(
            new StoreResource($store),
            $isAdmin ? Msg::CREATED : Msg::STORE_SUBMITTED,
        );
    }

    /** PUT /stores/{store} - admin. */
    public function update(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
        ]);

        $store->fill([
            'name' => $data['name'],
            'address' => $data['address'],
        ]);

        if (! empty($data['location_id'])) {
            $store->location_id = (int) $data['location_id'];
        }

        $store->save();
        $store->load('location.sector')->loadCount('prices');

        return ApiResponse::ok(new StoreResource($store), Msg::UPDATED);
    }

    /** PATCH /stores/{store}/verify - admin. */
    public function verify(Request $request, Store $store): JsonResponse
    {
        $data = $request->validate([
            'is_verified' => ['required', 'boolean'],
        ]);

        $store->update(['is_verified' => (bool) $data['is_verified']]);

        if ($store->is_verified) {
            $this->activity->log(
                ActivityLog::TYPE_STORE,
                Msg::activityStoreVerified($store->name),
                $request->user()?->id,
                $store,
            );
        }

        $store->load('location.sector')->loadCount('prices');

        return ApiResponse::ok(
            new StoreResource($store),
            $store->is_verified ? Msg::STORE_VERIFIED : Msg::STORE_UNVERIFIED,
        );
    }

    /**
     * DELETE /stores/{store} - admin.
     *
     * Soft delete so historic prices recorded at this store survive.
     */
    /**
     * The shop row is soft deleted; the prices submitted for it are removed.
     * The app shows that count before confirming, from
     * GET /admin/deletion-impact/store/{id}.
     */
    public function destroy(Store $store): JsonResponse
    {
        DB::transaction(function () use ($store): void {
            $this->impact->purge('store', $store->id);
            $store->delete();
        });

        return ApiResponse::action(Msg::DELETED);
    }
}
