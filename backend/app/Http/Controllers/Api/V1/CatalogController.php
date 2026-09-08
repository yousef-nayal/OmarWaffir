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

    public function destroySector(Sector $sector): JsonResponse
    {
        if ($sector->locations()->exists()) {
            return ApiResponse::fail(Msg::IN_USE, 409);
        }

        $sector->delete();

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

    public function destroyLocation(Location $location): JsonResponse
    {
        if ($location->stores()->exists() || $location->users()->exists()) {
            return ApiResponse::fail(Msg::IN_USE, 409);
        }

        $location->delete();

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
        if ($unit->prices()->exists() || $unit->officialPrices()->exists()) {
            return ApiResponse::fail(Msg::IN_USE, 409);
        }

        $unit->delete();

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
        if ($brand->prices()->exists()) {
            return ApiResponse::fail(Msg::IN_USE, 409);
        }

        $brand->delete();

        return ApiResponse::action(Msg::DELETED);
    }
}
