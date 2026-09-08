<?php

namespace Database\Seeders;

use App\Models\ActivityLog;
use App\Models\Brand;
use App\Models\Location;
use App\Models\OfficialPrice;
use App\Models\Price;
use App\Models\Product;
use App\Models\Rating;
use App\Models\Report;
use App\Models\Store;
use App\Models\Unit;
use App\Models\User;
use App\Support\Msg;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

/**
 * Stores, official-price history, submitted market prices, ratings and
 * reports - enough real data for the aggregation, the dashboard and every
 * admin screen to have something meaningful to show.
 */
class MarketDataSeeder extends Seeder
{
    public function run(): void
    {
        $data = require __DIR__.'/data/reference.php';

        $locations = Location::orderBy('id')->get()->values();
        $products = Product::orderBy('id')->get()->keyBy('name');
        $units = Unit::orderBy('id')->get()->keyBy('name');
        $brands = Brand::orderBy('id')->get()->values();
        $users = User::where('role', User::ROLE_USER)->orderBy('id')->get()->values();
        $admin = User::where('role', User::ROLE_ADMIN)->first();

        $productList = Product::orderBy('id')->get()->values();

        $stores = $this->seedStores($data, $locations, $users);
        $this->seedOfficialPrices($data, $productList, $units, $admin);
        $prices = $this->seedPrices($productList, $stores, $units, $brands, $users);
        $this->seedRatingsAndReports($prices, $users);
        $this->seedActivity($prices, $stores);
    }

    /** @return \Illuminate\Support\Collection<int, Store> */
    private function seedStores(array $data, $locations, $users)
    {
        foreach ($data['stores'] as $store) {
            Store::updateOrCreate(
                ['name' => $store['name']],
                [
                    'location_id' => $locations[$store['location'] - 1]->id,
                    'address' => $store['address'],
                    'is_verified' => $store['is_verified'],
                    'submitted_by_user_id' => null,
                ],
            );
        }

        // Additional stores so several districts have more than one shop and
        // the location filter has something to separate.
        $extra = [
            ['name' => 'سوبر ماركت الشهباء', 'address' => 'شارع الشهباء الرئيسي', 'location' => 90, 'verified' => true],
            ['name' => 'سوبر ماركت الفرقان', 'address' => 'جانب الحديقة', 'location' => 89, 'verified' => true],
            ['name' => 'ماركت الحمدانية', 'address' => 'الحي الأول', 'location' => 100, 'verified' => true],
            ['name' => 'بقالية السريان', 'address' => 'شارع السريان الجديدة', 'location' => 25, 'verified' => true],
            ['name' => 'سوبر ماركت صلاح الدين', 'address' => 'الشارع العام', 'location' => 76, 'verified' => true],
            ['name' => 'ماركت هنانو', 'address' => 'هنانو - المحور', 'location' => 51, 'verified' => false],
            ['name' => 'بقالية الجميلية', 'address' => 'قرب الساحة', 'location' => 18, 'verified' => true],
        ];

        foreach ($extra as $i => $store) {
            Store::updateOrCreate(
                ['name' => $store['name']],
                [
                    'location_id' => $locations[$store['location'] - 1]->id,
                    'address' => $store['address'],
                    'is_verified' => $store['verified'],
                    'submitted_by_user_id' => $store['verified'] ? null : $users[$i % $users->count()]->id,
                ],
            );
        }

        return Store::orderBy('id')->get()->values();
    }

    /**
     * Official prices are historical events, so each product gets a small
     * history: an older version and the current one.
     */
    private function seedOfficialPrices(array $data, $products, $units, ?User $admin): void
    {
        $unitById = $units->values();

        foreach ($data['official_prices'] as $row) {
            $product = $products[$row['product'] - 1] ?? null;
            $unit = $unitById[$row['unit'] - 1] ?? null;

            if ($product === null || $unit === null) {
                continue;
            }

            $current = (float) $row['price'];

            $versions = [
                ['price' => round($current * 0.86, 2), 'days' => 120],
                ['price' => round($current * 0.94, 2), 'days' => 60],
                ['price' => $current, 'days' => 12],
            ];

            foreach ($versions as $version) {
                OfficialPrice::firstOrCreate(
                    [
                        'product_id' => $product->id,
                        'unit_id' => $unit->id,
                        'amount' => $row['amount'],
                        'price' => $version['price'],
                    ],
                    [
                        'created_by' => $admin?->id,
                        'created_at' => Carbon::now()->subDays($version['days']),
                    ],
                );
            }
        }
    }

    /**
     * Submitted market prices spread across stores, districts and users.
     * A small number of deliberately abnormal values is included so the
     * outlier rejection in PriceAggregationService has something to reject.
     *
     * @return \Illuminate\Support\Collection<int, Price>
     */
    private function seedPrices($products, $stores, $units, $brands, $users)
    {
        if (Price::count() > 0) {
            return Price::orderBy('id')->get();
        }

        $seed = 20260908;
        mt_srand($seed);

        foreach ($products as $product) {
            $official = OfficialPrice::where('product_id', $product->id)
                ->orderByDesc('id')
                ->first();

            if ($official === null) {
                continue;
            }

            $base = (float) $official->price;
            $unitId = $official->unit_id;
            $amount = (float) $official->amount;

            // Seven submissions per product, in seven different shops.
            $shops = $stores->shuffle()->take(7);

            foreach ($shops as $index => $store) {
                $user = $users[($product->id + $index) % $users->count()];
                $brand = $brands[($product->id + $index) % $brands->count()];

                // Most submissions sit within +/- 18% of the official price.
                $factor = 1 + (mt_rand(-12, 18) / 100);

                // Two products get one clearly abnormal submission each.
                $isOutlier = $index === 6 && $product->id % 7 === 0;
                if ($isOutlier) {
                    $factor = 3.4;
                }

                // Some rows are submitted in a multiple of the official amount
                // so amount normalisation is exercised.
                $multiplier = $index % 3 === 2 ? 2 : 1;

                Price::create([
                    'user_id' => $user->id,
                    'store_id' => $store->id,
                    'product_id' => $product->id,
                    'unit_id' => $unitId,
                    'brand_id' => $brand->id,
                    'amount' => $amount * $multiplier,
                    'price' => round($base * $factor * $multiplier, 2),
                    'created_at' => Carbon::now()->subDays(mt_rand(0, 21))->subHours(mt_rand(0, 23)),
                    'updated_at' => Carbon::now(),
                ]);
            }
        }

        mt_srand();

        return Price::orderBy('id')->get();
    }

    private function seedRatingsAndReports($prices, $users): void
    {
        if (Rating::count() > 0 && Report::count() > 0) {
            return;
        }

        $types = Report::types();

        foreach ($prices as $index => $price) {
            // Two votes on roughly every second price, never by its author.
            if ($index % 2 === 0) {
                foreach ([1, 2] as $offset) {
                    $voter = $users[($index + $offset) % $users->count()];

                    if ($voter->id === $price->user_id) {
                        continue;
                    }

                    Rating::updateOrCreate(
                        ['user_id' => $voter->id, 'price_id' => $price->id],
                        ['value' => ($index + $offset) % 3 !== 0],
                    );
                }
            }

            // A report on roughly every ninth price.
            if ($index % 9 === 4) {
                $reporter = $users[($index + 3) % $users->count()];

                if ($reporter->id === $price->user_id) {
                    $reporter = $users[($index + 4) % $users->count()];
                }

                $type = $types[$index % count($types)];

                Report::create([
                    'user_id' => $reporter->id,
                    'price_id' => $price->id,
                    'type' => $type,
                    'description' => Report::requiresDescription($type)
                        ? 'يرجى التحقق من بيانات هذا السعر'
                        : null,
                    'created_at' => $price->created_at?->copy()->addHours(3) ?? Carbon::now(),
                    'updated_at' => Carbon::now(),
                ]);
            }
        }
    }

    private function seedActivity($prices, $stores): void
    {
        if (ActivityLog::count() > 0) {
            return;
        }

        foreach ($prices->sortByDesc('created_at')->take(12) as $price) {
            $price->loadMissing(['user', 'product', 'store']);

            ActivityLog::create([
                'type' => ActivityLog::TYPE_PRICE,
                'text' => Msg::activityPriceAdded(
                    $price->user?->name ?? '',
                    $price->product?->name ?? '',
                    $price->store?->name ?? '',
                ),
                'user_id' => $price->user_id,
                'subject_type' => Price::class,
                'subject_id' => $price->id,
                'created_at' => $price->created_at,
                'updated_at' => $price->created_at,
            ]);
        }

        foreach (Report::with(['user', 'price.product'])->latest('id')->take(5)->get() as $report) {
            ActivityLog::create([
                'type' => ActivityLog::TYPE_REPORT,
                'text' => Msg::activityReportAdded(
                    $report->user?->name ?? '',
                    $report->price?->product?->name ?? '',
                ),
                'user_id' => $report->user_id,
                'subject_type' => Report::class,
                'subject_id' => $report->id,
                'created_at' => $report->created_at,
                'updated_at' => $report->created_at,
            ]);
        }

        foreach ($stores->where('is_verified', false)->take(3) as $store) {
            ActivityLog::create([
                'type' => ActivityLog::TYPE_STORE,
                'text' => Msg::activityStoreSubmitted('مستخدم', $store->name),
                'user_id' => $store->submitted_by_user_id,
                'subject_type' => Store::class,
                'subject_id' => $store->id,
                'created_at' => Carbon::now()->subDays(2),
                'updated_at' => Carbon::now()->subDays(2),
            ]);
        }
    }
}
