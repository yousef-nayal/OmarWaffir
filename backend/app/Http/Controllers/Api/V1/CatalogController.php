<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\BrandResource;
use App\Http\Resources\LocationResource;
use App\Http\Resources\SectorResource;
use App\Http\Resources\UnitResource;
use App\Models\Brand;
use App\Models\Location;
use App\Models\Sector;
use App\Models\Unit;
use App\Services\DeletionImpactService;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Reference data: sectors, locations, units and brands.
 *
 * The GET endpoints are public because the registration and store-suggestion
 * forms need them before a session exists. Every mutation is admin only
 * (enforced in routes/api.php).
 */
class CatalogController extends Controller
{
    public function __construct(private readonly DeletionImpactService $impact)
    {
    }

    // ── Sectors ────────────────────────────────────────────────────────────

    public function sectors(): JsonResponse
    {
        $sectors = Sector::withCount('locations')->orderBy('id')->get();

        return ApiResponse::ok(SectorResource::collection($sectors), Msg::FETCHED);
    }

    public function storeSector(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('sectors', 'name')->whereNull('deleted_at')],
            'description' => ['nullable', 'string', 'max:1000'],
        ]);

        $sector = Sector::create($data);

        return ApiResponse::created(new SectorResource($sector->loadCount('locations')));
    }

    public function updateSector(Request $request, Sector $sector): JsonResponse
    {
        $data = $request->validate([
            'name' => [
                'required', 'string', 'max:255',
                Rule::unique('sectors', 'name')->ignore($sector->id)->whereNull('deleted_at'),
            ],
            'description' => ['nullable', 'string', 'max:1000'],
        ]);

        $sector->update($data);

        return ApiResponse::ok(new SectorResource($sector->loadCount('locations')), Msg::UPDATED);
    }

    /**
     * Deleting a block takes its areas with it - and the shops and prices
     * recorded in them. The admin is shown those numbers first: the app reads
     * them from GET /admin/deletion-impact/sector/{id}.
     */
    public function destroySector(Sector $sector): JsonResponse
    {
        DB::transaction(function () use ($sector): void {
            $this->impact->purge('sector', $sector->id);
            $sector->delete();
        });

        return ApiResponse::action(Msg::DELETED);
    }

    // ── Locations ──────────────────────────────────────────────────────────

    public function locations(Request $request): JsonResponse
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'sector_id' => ['nullable', 'integer', 'exists:sectors,id'],
        ]);

        $query = Location::with('sector')->withCount('stores');

        if (! empty($filters['search'])) {
            $query->where('district', 'ILIKE', '%'.$filters['search'].'%');
        }

        if (! empty($filters['sector_id'])) {
            $query->where('sector_id', (int) $filters['sector_id']);
        }

        $locations = $query->orderBy('sector_id')->orderBy('id')->get();

        return ApiResponse::ok(LocationResource::collection($locations), Msg::FETCHED);
    }

    public function storeLocation(Request $request): JsonResponse
    {
        $data = $request->validate([
            'sector_id' => ['required', 'integer', 'exists:sectors,id'],
            'district' => ['required', 'string', 'max:255'],
        ]);

        $exists = Location::where('sector_id', (int) $data['sector_id'])
            ->where('district', $data['district'])
            ->exists();

        if ($exists) {
            return ApiResponse::fail(Msg::VALIDATION, 422, [
                'district' => [__('validation.unique', ['attribute' => __('validation.attributes.district')])],
            ]);
        }

        $location = Location::create([
            'sector_id' => (int) $data['sector_id'],
            'district' => $data['district'],
        ]);

        return ApiResponse::created(new LocationResource($location->load('sector')->loadCount('stores')));
    }

    public function updateLocation(Request $request, Location $location): JsonResponse
    {
        $data = $request->validate([
            'sector_id' => ['required', 'integer', 'exists:sectors,id'],
            'district' => ['required', 'string', 'max:255'],
        ]);

        $location->update([
            'sector_id' => (int) $data['sector_id'],
            'district' => $data['district'],
        ]);

        return ApiResponse::ok(
            new LocationResource($location->load('sector')->loadCount('stores')),
            Msg::UPDATED,
        );
    }

    /**
     * The shops of an area cannot outlive it (stores.location_id is not
     * nullable), so they go, and their prices with them. Residents keep their
     * account and simply lose the link.
     */
    public function destroyLocation(Location $location): JsonResponse
    {
        DB::transaction(function () use ($location): void {
            // purge() deletes the area itself along with its shops.
            $this->impact->purge('location', $location->id);
        });

        return ApiResponse::action(Msg::DELETED);
    }

    // ── Units ──────────────────────────────────────────────────────────────

    public function units(): JsonResponse
    {
        $units = Unit::withCount(['prices', 'officialPrices'])->orderBy('id')->get();

        return ApiResponse::ok(UnitResource::collection($units), Msg::FETCHED);
    }

    public function storeUnit(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:units,name'],
        ]);

        $unit = Unit::create($data);

        return ApiResponse::created(new UnitResource($unit->loadCount(['prices', 'officialPrices'])));
    }

    public function updateUnit(Request $request, Unit $unit): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('units', 'name')->ignore($unit->id)],
        ]);

        $unit->update($data);

        return ApiResponse::ok(
            new UnitResource($unit->loadCount(['prices', 'officialPrices'])),
            Msg::UPDATED,
        );
    }

    public function destroyUnit(Unit $unit): JsonResponse
    {
        DB::transaction(function () use ($unit): void {
            $this->impact->purge('unit', $unit->id);
            $unit->delete();
        });

        return ApiResponse::action(Msg::DELETED);
    }

    // ── Brands ─────────────────────────────────────────────────────────────

    public function brands(): JsonResponse
    {
        $brands = Brand::query()
            ->withCount('prices')
            // COUNT(DISTINCT ...) needs a correlated subquery on PostgreSQL;
            // withCount()+distinct() would produce an invalid GROUP BY.
            ->addSelect(['products_count' => DB::table('prices')
                ->selectRaw('COUNT(DISTINCT product_id)')
                ->whereColumn('prices.brand_id', 'brands.id'),
            ])
            ->orderBy('id')
            ->get();

        return ApiResponse::ok(BrandResource::collection($brands), Msg::FETCHED);
    }

    public function storeBrand(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:brands,name'],
        ]);

        $brand = Brand::create($data);

        return ApiResponse::created(new BrandResource($brand->loadCount('prices')));
    }

    public function updateBrand(Request $request, Brand $brand): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('brands', 'name')->ignore($brand->id)],
        ]);

        $brand->update($data);

        return ApiResponse::ok(new BrandResource($brand->loadCount('prices')), Msg::UPDATED);
    }

    public function destroyBrand(Brand $brand): JsonResponse
    {
        DB::transaction(function () use ($brand): void {
            $this->impact->purge('brand', $brand->id);
            $brand->delete();
        });

        return ApiResponse::action(Msg::DELETED);
    }
}
