<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\OfficialPriceHistoryResource;
use App\Http\Resources\OfficialPriceResource;
use App\Models\ActivityLog;
use App\Models\OfficialPrice;
use App\Models\User;
use App\Notifications\OfficialPriceChanged;
use App\Services\ActivityLogger;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Notification;

/**
 * Official prices are immutable historical events. "Updating" one inserts a
 * new version so the history screen keeps every previous value.
 */
class OfficialPriceController extends Controller
{
    public function __construct(private readonly ActivityLogger $activity)
    {
    }

    /** GET /official-prices?search=&product_id=&page=&per_page= */
    public function index(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'product_id' => ['nullable', 'integer', 'exists:products,id'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:200'],
        ]);

        $query = OfficialPrice::query()
            ->current()
            ->with(['product', 'unit']);

        if (! empty($filters['search'])) {
            $query->whereHas(
                'product',
                fn ($q) => $q->where('name', 'ILIKE', '%'.$filters['search'].'%'),
            );
        }

        if (! empty($filters['product_id'])) {
            $query->where('product_id', (int) $filters['product_id']);
        }

        $paginator = $query->orderByDesc('created_at')
            ->paginate((int) ($filters['per_page'] ?? 100))
            ->withQueryString();

        return ApiResponse::paginated($paginator, OfficialPriceResource::class);
    }

    /**
     * GET /official-prices/{officialPrice}/history
     *
     * Every recorded version for the same product/unit series, newest first.
     */
    public function history(OfficialPrice $officialPrice): JsonResponse
    {
        $history = OfficialPrice::query()
            ->with('unit')
            ->where('product_id', $officialPrice->product_id)
            ->where('unit_id', $officialPrice->unit_id)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get();

        return ApiResponse::ok(
            OfficialPriceHistoryResource::collection($history),
            Msg::FETCHED,
        );
    }

    /** POST /official-prices - admin. */
    public function store(Request $request): JsonResponse
    {
        $data = $this->validatePayload($request);

        $previous = $this->currentPriceFor((int) $data['product_id'], (int) $data['unit_id']);

        $officialPrice = $this->createVersion($data, $request->user()?->id);

        $this->announce($officialPrice, $previous);

        return ApiResponse::created(new OfficialPriceResource($officialPrice));
    }

    /**
     * PUT /official-prices/{officialPrice} - admin.
     *
     * Inserts a NEW version instead of overwriting: the previous row stays
     * visible in the history screen.
     */
    public function update(Request $request, OfficialPrice $officialPrice): JsonResponse
    {
        $data = $this->validatePayload($request);

        $previous = (float) $officialPrice->price;

        $version = $this->createVersion($data, $request->user()?->id);

        $this->announce($version, $previous);

        return ApiResponse::ok(new OfficialPriceResource($version), Msg::UPDATED);
    }

    /** DELETE /official-prices/{officialPrice} - admin. */
    public function destroy(OfficialPrice $officialPrice): JsonResponse
    {
        $officialPrice->delete();

        return ApiResponse::action(Msg::DELETED);
    }

    /** @return array<string, mixed> */
    private function validatePayload(Request $request): array
    {
        return $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'unit_id' => ['required', 'integer', 'exists:units,id'],
            'amount' => ['required', 'numeric', 'gt:0', 'max:999999'],
            'price' => ['required', 'numeric', 'min:0', 'max:9999999999'],
        ]);
    }

    /** @param array<string, mixed> $data */
    private function createVersion(array $data, ?int $createdBy): OfficialPrice
    {
        return DB::transaction(function () use ($data, $createdBy) {
            $officialPrice = OfficialPrice::create([
                'product_id' => (int) $data['product_id'],
                'unit_id' => (int) $data['unit_id'],
                'amount' => $data['amount'],
                'price' => $data['price'],
                'created_by' => $createdBy,
                'created_at' => Carbon::now(),
            ]);

            return $officialPrice->load(['product', 'unit']);
        });
    }

    private function currentPriceFor(int $productId, int $unitId): ?float
    {
        $current = OfficialPrice::where('product_id', $productId)
            ->where('unit_id', $unitId)
            ->orderByDesc('id')
            ->first();

        return $current !== null ? (float) $current->price : null;
    }

    private function announce(OfficialPrice $officialPrice, ?float $previous): void
    {
        $this->activity->log(
            ActivityLog::TYPE_OFFICIAL,
            Msg::activityOfficialPrice(
                $officialPrice->product?->name ?? '',
                rtrim(rtrim(number_format((float) $officialPrice->price, 2, '.', ''), '0'), '.'),
            ),
            $officialPrice->created_by,
            $officialPrice,
        );

        // In-app notification for every active normal user.
        User::query()
            ->where('is_active', true)
            ->where('role', User::ROLE_USER)
            ->whereNotNull('phone_verified_at')
            ->chunkById(200, function ($users) use ($officialPrice, $previous) {
                Notification::send($users, new OfficialPriceChanged($officialPrice, $previous));
            });
    }
}
