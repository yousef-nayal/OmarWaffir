<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PriceResource;
use App\Models\ActivityLog;
use App\Models\Price;
use App\Models\Rating;
use App\Services\ActivityLogger;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PriceController extends Controller
{
    public function __construct(private readonly ActivityLogger $activity)
    {
    }

    /**
     * GET /prices - primarily the administrative review list.
     *
     * Filters: search, user_id, product_id, store_id, sector_id, location_id,
     * brand_id, from, to, page, per_page.
     */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'user_id' => ['nullable', 'integer', 'exists:users,id'],
            'product_id' => ['nullable', 'integer', 'exists:products,id'],
            'store_id' => ['nullable', 'integer', 'exists:stores,id'],
            'sector_id' => ['nullable', 'integer', 'exists:sectors,id'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'brand_id' => ['nullable', 'integer', 'exists:brands,id'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = Price::query()
            ->with(['product', 'unit', 'brand', 'user', 'store.location.sector'])
            ->withCount([
                'ratings as thumbs_up' => fn ($q) => $q->where('value', true),
                'ratings as thumbs_down' => fn ($q) => $q->where('value', false),
            ]);

        if (! empty($filters['search'])) {
            $search = '%'.$filters['search'].'%';
            $query->where(function ($q) use ($search) {
                $q->whereHas('product', fn ($p) => $p->where('name', 'ILIKE', $search))
                    ->orWhereHas('store', fn ($s) => $s->where('name', 'ILIKE', $search))
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'ILIKE', $search));
            });
        }

        foreach (['user_id', 'product_id', 'store_id', 'brand_id'] as $column) {
            if (! empty($filters[$column])) {
                $query->where($column, (int) $filters[$column]);
            }
        }

        if (! empty($filters['location_id'])) {
            $query->whereHas('store', fn ($q) => $q->where('location_id', (int) $filters['location_id']));
        }

        if (! empty($filters['sector_id'])) {
            $query->whereHas(
                'store.location',
                fn ($q) => $q->where('sector_id', (int) $filters['sector_id']),
            );
        }

        if (! empty($filters['from'])) {
            $query->where('created_at', '>=', $filters['from']);
        }

        if (! empty($filters['to'])) {
            $query->where('created_at', '<=', $filters['to']);
        }

        $paginator = $query->orderByDesc('created_at')
            ->paginate((int) ($filters['per_page'] ?? 20))
            ->withQueryString();

        return ApiResponse::paginated($paginator, PriceResource::class);
    }

    /**
     * POST /prices
     *
     * user_id always comes from the authenticated user, never from the body.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'store_id' => ['required', 'integer', 'exists:stores,id'],
            'unit_id' => ['required', 'integer', 'exists:units,id'],
            'brand_id' => ['nullable', 'integer', 'exists:brands,id'],
            'amount' => ['required', 'numeric', 'gt:0', 'max:999999'],
            'price' => ['required', 'numeric', 'min:0', 'max:9999999999'],
        ]);

        $user = $request->user();

        $price = Price::create([
            'user_id' => $user->id,
            'product_id' => (int) $data['product_id'],
            'store_id' => (int) $data['store_id'],
            'unit_id' => (int) $data['unit_id'],
            'brand_id' => isset($data['brand_id']) ? (int) $data['brand_id'] : null,
            'amount' => $data['amount'],
            'price' => $data['price'],
        ]);

        $price->load(['product', 'unit', 'brand', 'user', 'store.location.sector']);

        $this->activity->log(
            ActivityLog::TYPE_PRICE,
            Msg::activityPriceAdded($user->name, $price->product?->name ?? '', $price->store?->name ?? ''),
            $user->id,
            $price,
        );

        return ApiResponse::created(new PriceResource($price), Msg::PRICE_SUBMITTED);
    }

    /**
     * POST /prices/{price}/vote
     *
     * One vote per user per price. Voting again with the same value is
     * idempotent; a different value updates the existing rating. Users may not
     * rate their own submissions.
     */
    public function vote(Request $request, Price $price): JsonResponse
    {
        $data = $request->validate([
            'is_up' => ['required', 'boolean'],
        ]);

        $user = $request->user();

        if ($price->user_id === $user->id) {
            return ApiResponse::fail(Msg::SELF_VOTE, 403);
        }

        DB::transaction(function () use ($price, $user, $data) {
            // The unique index on (user_id, price_id) is the final guarantee.
            Rating::updateOrCreate(
                ['user_id' => $user->id, 'price_id' => $price->id],
                ['value' => (bool) $data['is_up']],
            );
        });

        $price->loadCount([
            'ratings as thumbs_up' => fn ($q) => $q->where('value', true),
            'ratings as thumbs_down' => fn ($q) => $q->where('value', false),
        ])->load(['product', 'unit', 'brand', 'user', 'store.location.sector']);

        return ApiResponse::ok(new PriceResource($price), Msg::VOTE_SAVED);
    }

    /**
     * DELETE /prices/{price} - admin review action.
     *
     * Prices have no approval lifecycle; removing an incorrect one IS the
     * review outcome. Ratings and reports cascade with it.
     */
    public function destroy(Price $price): JsonResponse
    {
        $price->delete();

        return ApiResponse::action(Msg::DELETED);
    }
}
