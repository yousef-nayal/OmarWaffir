<?php

namespace App\Services;

use App\Models\OfficialPrice;
use App\Models\Price;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Representative real market price.
 *
 * The thesis asks for a market figure that is not dragged around by a handful
 * of abnormal submissions. The implementation is a median with robust outlier
 * rejection:
 *
 *   1. take recent price events for the product (configurable freshness window)
 *   2. restrict them to stores inside the requested location, when one is given
 *   3. normalise every event to a price for ONE unit  (price / amount)
 *   4. drop non-positive values
 *   5. reject outliers with the median absolute deviation (modified z-score),
 *      falling back to the inter-quartile range when the MAD cannot
 *      discriminate, and skipping filtering entirely for tiny samples
 *   6. real_price = median(kept), avg_price = mean(kept)
 *
 * Everything is expressed back in the official price amount so the two numbers
 * are directly comparable in the UI.
 *
 * The pure numeric core lives in representative() and is unit tested.
 */
class PriceAggregationService
{
    /**
     * Aggregate a single product.
     *
     * @return array<string, mixed>
     */
    public function forProduct(int $productId, ?int $locationId = null): array
    {
        return $this->forProducts([$productId], $locationId)[$productId];
    }

    /**
     * Aggregate many products with a fixed number of queries (no N+1).
     *
     * @param  list<int>  $productIds
     * @return array<int, array<string, mixed>>
     */
    public function forProducts(array $productIds, ?int $locationId = null): array
    {
        $productIds = array_values(array_unique(array_map('intval', $productIds)));

        if ($productIds === []) {
            return [];
        }

        $officials = $this->currentOfficialPrices($productIds);
        $prices = $this->recentPrices($productIds, $locationId);

        $result = [];

        foreach ($productIds as $productId) {
            $official = $officials[$productId] ?? null;
            $rows = $prices->get($productId, collect());

            // Only compare like with like: when an official price exists we
            // aggregate the submissions recorded in that same unit.
            $unitId = $official?->unit_id ?? $this->modalUnitId($rows);
            $unitName = $official?->unit?->name ?? $this->unitNameFor($rows, $unitId);
            $officialAmount = $official !== null ? (float) $official->amount : 1.0;

            $relevant = $unitId === null
                ? collect()
                : $rows->where('unit_id', $unitId);

            $unitValues = $relevant
                ->map(fn (Price $p): float => $p->unitPrice())
                ->filter(fn (float $v): bool => $v > 0)
                ->values()
                ->all();

            $stats = $this->representative($unitValues);

            $officialPrice = $official !== null ? (float) $official->price : 0.0;
            $realPrice = $stats['median'] * $officialAmount;
            $avgPrice = $stats['mean'] * $officialAmount;

            $changePercent = 0.0;
            if ($officialPrice > 0 && $realPrice > 0) {
                $changePercent = round((($realPrice - $officialPrice) / $officialPrice) * 100, 2);
            }

            $result[$productId] = [
                'official_price' => round($officialPrice, 2),
                'real_price' => round($realPrice, 2),
                'avg_price' => round($avgPrice, 2),
                'unit' => $unitName ?? '',
                'unit_id' => $unitId !== null ? (string) $unitId : null,
                'amount' => $officialAmount,
                'prices_count' => $relevant->count(),
                'kept_samples' => $stats['kept'],
                'change_percent' => $changePercent,
                'is_price_up' => $realPrice >= $officialPrice,
                'official_price_id' => $official !== null ? (string) $official->id : null,
            ];
        }

        return $result;
    }

    /**
     * The pure numeric core: median/mean after robust outlier rejection.
     *
     * @param  list<float>  $values
     * @return array{median: float, mean: float, kept: int, filtered: list<float>}
     */
    public function representative(array $values): array
    {
        $values = array_values(array_filter($values, static fn ($v): bool => is_numeric($v) && $v > 0));

        if ($values === []) {
            return ['median' => 0.0, 'mean' => 0.0, 'kept' => 0, 'filtered' => []];
        }

        $kept = $this->rejectOutliers($values);

        return [
            'median' => $this->median($kept),
            'mean' => array_sum($kept) / count($kept),
            'kept' => count($kept),
            'filtered' => $kept,
        ];
    }

    /**
     * @param  list<float>  $values
     * @return list<float>
     */
    public function rejectOutliers(array $values): array
    {
        $minSamples = (int) config('waffir.pricing.min_samples_for_filter', 5);

        // With very few submissions any filter would be guesswork; keep them all.
        if (count($values) < $minSamples) {
            return array_values($values);
        }

        $median = $this->median($values);
        $deviations = array_map(static fn (float $v): float => abs($v - $median), $values);
        $mad = $this->median($deviations);

        if ($mad > 0.0) {
            $threshold = (float) config('waffir.pricing.mad_threshold', 3.5);

            // 0.6745 makes the MAD a consistent estimator of sigma for normally
            // distributed data (Iglewicz and Hoaglin).
            $kept = array_values(array_filter(
                $values,
                static fn (float $v): bool => abs(0.6745 * ($v - $median) / $mad) <= $threshold,
            ));

            return $kept === [] ? array_values($values) : $kept;
        }

        // MAD cannot discriminate (more than half the values are identical):
        // fall back to the inter-quartile range.
        $kept = $this->rejectByIqr($values);

        if (count($kept) < count($values)) {
            return $kept;
        }

        // Both MAD and IQR are zero, which happens when at least three
        // quarters of the submissions are the same number. The mean absolute
        // deviation is the documented last-resort scale estimator for the
        // modified z-score (Iglewicz and Hoaglin), and it still isolates a
        // single wild value that MAD and IQR are blind to.
        $kept = $this->rejectByMeanAbsoluteDeviation($values, $median);

        return $kept === [] ? array_values($values) : $kept;
    }

    /**
     * @param  list<float>  $values
     * @return list<float>
     */
    private function rejectByMeanAbsoluteDeviation(array $values, float $median): array
    {
        $count = count($values);
        $meanAd = array_sum(array_map(
            static fn (float $v): float => abs($v - $median),
            $values,
        )) / $count;

        if ($meanAd <= 0.0) {
            return array_values($values);
        }

        $threshold = (float) config('waffir.pricing.mad_threshold', 3.5);

        return array_values(array_filter(
            $values,
            static fn (float $v): bool => abs(($v - $median) / (1.253314 * $meanAd)) <= $threshold,
        ));
    }

    /**
     * @param  list<float>  $values
     * @return list<float>
     */
    private function rejectByIqr(array $values): array
    {
        $sorted = $values;
        sort($sorted);

        $q1 = $this->percentile($sorted, 0.25);
        $q3 = $this->percentile($sorted, 0.75);
        $iqr = $q3 - $q1;

        if ($iqr <= 0.0) {
            return array_values($values);
        }

        $k = (float) config('waffir.pricing.iqr_multiplier', 1.5);
        $low = $q1 - ($k * $iqr);
        $high = $q3 + ($k * $iqr);

        return array_values(array_filter(
            $values,
            static fn (float $v): bool => $v >= $low && $v <= $high,
        ));
    }

    /** @param list<float> $values */
    public function median(array $values): float
    {
        if ($values === []) {
            return 0.0;
        }

        $sorted = $values;
        sort($sorted);
        $count = count($sorted);
        $middle = intdiv($count, 2);

        return $count % 2 === 1
            ? (float) $sorted[$middle]
            : ((float) $sorted[$middle - 1] + (float) $sorted[$middle]) / 2;
    }

    /** @param list<float> $sorted */
    private function percentile(array $sorted, float $p): float
    {
        $count = count($sorted);

        if ($count === 0) {
            return 0.0;
        }

        $index = ($count - 1) * $p;
        $lower = (int) floor($index);
        $upper = (int) ceil($index);

        if ($lower === $upper) {
            return (float) $sorted[$lower];
        }

        return (float) $sorted[$lower] + (($index - $lower) * ((float) $sorted[$upper] - (float) $sorted[$lower]));
    }

    /**
     * Current official price per product (newest row wins).
     *
     * @param  list<int>  $productIds
     * @return array<int, OfficialPrice>
     */
    private function currentOfficialPrices(array $productIds): array
    {
        return OfficialPrice::with('unit')
            ->whereIn('product_id', $productIds)
            ->whereIn('id', function ($sub) use ($productIds) {
                $sub->selectRaw('MAX(id)')
                    ->from('official_prices')
                    ->whereIn('product_id', $productIds)
                    ->groupBy('product_id');
            })
            ->get()
            ->keyBy('product_id')
            ->all();
    }

    /**
     * @param  list<int>  $productIds
     * @return Collection<int, Collection<int, Price>>
     */
    private function recentPrices(array $productIds, ?int $locationId): Collection
    {
        $since = Carbon::now()->subDays((int) config('waffir.pricing.freshness_days', 30));

        $query = Price::with('unit')
            ->whereIn('product_id', $productIds)
            ->where('created_at', '>=', $since);

        if ($locationId !== null) {
            $query->whereHas('store', fn ($q) => $q->where('location_id', $locationId));
        }

        return $query->get()->groupBy('product_id');
    }

    /** @param Collection<int, Price> $rows */
    private function modalUnitId(Collection $rows): ?int
    {
        if ($rows->isEmpty()) {
            return null;
        }

        $counts = $rows->groupBy('unit_id')->map->count()->sortDesc();

        return $counts->isEmpty() ? null : (int) $counts->keys()->first();
    }

    /** @param Collection<int, Price> $rows */
    private function unitNameFor(Collection $rows, ?int $unitId): ?string
    {
        if ($unitId === null) {
            return null;
        }

        return $rows->firstWhere('unit_id', $unitId)?->unit?->name;
    }
}
