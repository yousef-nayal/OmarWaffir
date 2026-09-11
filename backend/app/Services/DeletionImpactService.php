<?php

namespace App\Services;

use App\Models\Brand;
use App\Models\Location;
use App\Models\OfficialPrice;
use App\Models\Price;
use App\Models\Product;
use App\Models\Sector;
use App\Models\Store;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Support\Collection;
use InvalidArgumentException;

/**
 * What disappears with a catalogue row, and the deletion itself.
 *
 * Deleting a unit, brand, product, store, user, area or block takes the market
 * prices recorded against it with it: a price row cannot exist without all of
 * them, and leaving orphans behind is what the restrict-on-delete constraints
 * were preventing by refusing the delete outright.
 *
 * Two questions, one place to answer them, so the warning the admin reads
 * before confirming and the rows that actually go are never out of step:
 *
 *   impact() - counted, for the confirmation dialog
 *   purge()  - the same set, deleted
 *
 * Ratings and reports hang off prices with ON DELETE CASCADE, so they follow
 * the prices without being named here.
 */
class DeletionImpactService
{
    public const TYPES = ['unit', 'brand', 'product', 'store', 'user', 'location', 'sector'];

    /**
     * @return array{prices: int, official_prices: int, stores: int, locations: int, users: int}
     */
    public function impact(string $type, int $id): array
    {
        return match ($this->assertType($type)) {
            'unit' => $this->counts(
                prices: Price::where('unit_id', $id)->count(),
                officialPrices: OfficialPrice::where('unit_id', $id)->count(),
            ),
            'brand' => $this->counts(
                prices: Price::where('brand_id', $id)->count(),
            ),
            'product' => $this->counts(
                prices: Price::where('product_id', $id)->count(),
                officialPrices: OfficialPrice::where('product_id', $id)->count(),
            ),
            'store' => $this->counts(
                prices: Price::where('store_id', $id)->count(),
            ),
            'user' => $this->counts(
                prices: Price::where('user_id', $id)->count(),
            ),
            'location' => $this->locationImpact([$id]),
            'sector' => $this->locationImpact($this->locationIdsOfSector($id)),
        };
    }

    /**
     * Delete everything impact() counted. Call inside a transaction: the caller
     * still has to delete the row itself.
     */
    public function purge(string $type, int $id): void
    {
        match ($this->assertType($type)) {
            'unit' => $this->purgeBy(['unit_id' => $id], withOfficial: true),
            'brand' => $this->purgeBy(['brand_id' => $id]),
            'product' => $this->purgeBy(['product_id' => $id], withOfficial: true),
            'store' => $this->purgeBy(['store_id' => $id]),
            'user' => $this->purgeBy(['user_id' => $id]),
            'location' => $this->purgeLocations([$id]),
            'sector' => $this->purgeLocations($this->locationIdsOfSector($id)),
        };
    }

    /**
     * @param  array<string, int>  $where
     */
    private function purgeBy(array $where, bool $withOfficial = false): void
    {
        Price::where($where)->delete();

        if ($withOfficial) {
            OfficialPrice::where($where)->delete();
        }
    }

    /**
     * An area cannot be emptied of its shops: stores.location_id is not
     * nullable, so the shops recorded there go with it, and their prices with
     * them. Residents only lose the link - the account itself stays.
     *
     * @param  list<int>  $locationIds
     */
    private function purgeLocations(array $locationIds): void
    {
        if ($locationIds === []) {
            return;
        }

        $storeIds = $this->storeIdsIn($locationIds)->all();

        if ($storeIds !== []) {
            Price::whereIn('store_id', $storeIds)->delete();
            Store::withTrashed()->whereIn('id', $storeIds)->forceDelete();
        }

        User::withTrashed()
            ->whereIn('location_id', $locationIds)
            ->update(['location_id' => null]);

        Location::whereIn('id', $locationIds)->delete();
    }

    /**
     * @param  list<int>  $locationIds
     * @return array{prices: int, official_prices: int, stores: int, locations: int, users: int}
     */
    private function locationImpact(array $locationIds): array
    {
        if ($locationIds === []) {
            return $this->counts();
        }

        $storeIds = $this->storeIdsIn($locationIds);

        return $this->counts(
            prices: $storeIds->isEmpty() ? 0 : Price::whereIn('store_id', $storeIds->all())->count(),
            stores: $storeIds->count(),
            locations: count($locationIds),
            users: User::withTrashed()->whereIn('location_id', $locationIds)->count(),
        );
    }

    /**
     * Soft-deleted shops still hold the foreign key, so they have to be counted
     * and force-deleted too - otherwise the area refuses to go.
     *
     * @param  list<int>  $locationIds
     * @return Collection<int, int>
     */
    private function storeIdsIn(array $locationIds): Collection
    {
        return Store::withTrashed()->whereIn('location_id', $locationIds)->pluck('id');
    }

    /** @return list<int> */
    private function locationIdsOfSector(int $sectorId): array
    {
        return Location::where('sector_id', $sectorId)->pluck('id')->all();
    }

    /**
     * @return array{prices: int, official_prices: int, stores: int, locations: int, users: int}
     */
    private function counts(
        int $prices = 0,
        int $officialPrices = 0,
        int $stores = 0,
        int $locations = 0,
        int $users = 0,
    ): array {
        return [
            'prices' => $prices,
            'official_prices' => $officialPrices,
            'stores' => $stores,
            'locations' => $locations,
            'users' => $users,
        ];
    }

    private function assertType(string $type): string
    {
        if (! in_array($type, self::TYPES, true)) {
            throw new InvalidArgumentException("Unknown deletable type [{$type}].");
        }

        return $type;
    }

    /** Guards against a signature drift between the models and this service. */
    public function modelFor(string $type): string
    {
        return match ($this->assertType($type)) {
            'unit' => Unit::class,
            'brand' => Brand::class,
            'product' => Product::class,
            'store' => Store::class,
            'user' => User::class,
            'location' => Location::class,
            'sector' => Sector::class,
        };
    }
}
