<?php

namespace Tests\Unit;

use App\Services\PriceAggregationService;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The numeric core of the representative-price algorithm.
 *
 * These cases do not touch the database: they pin down the median, the MAD
 * based outlier rejection, the IQR fallback and the small-sample behaviour.
 */
class PriceAggregationServiceTest extends TestCase
{
    private PriceAggregationService $service;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = new PriceAggregationService();

        config()->set('waffir.pricing.min_samples_for_filter', 5);
        config()->set('waffir.pricing.mad_threshold', 3.5);
        config()->set('waffir.pricing.iqr_multiplier', 1.5);
    }

    #[Test]
    public function it_returns_zeroes_when_there_are_no_values(): void
    {
        $result = $this->service->representative([]);

        $this->assertSame(0.0, $result['median']);
        $this->assertSame(0.0, $result['mean']);
        $this->assertSame(0, $result['kept']);
    }

    #[Test]
    public function it_computes_the_median_of_an_odd_sample(): void
    {
        $this->assertSame(100.0, $this->service->median([90.0, 100.0, 130.0]));
    }

    #[Test]
    public function it_computes_the_median_of_an_even_sample(): void
    {
        $this->assertSame(105.0, $this->service->median([90.0, 100.0, 110.0, 130.0]));
    }

    #[Test]
    public function it_drops_non_positive_values(): void
    {
        $result = $this->service->representative([100.0, -50.0, 0.0, 110.0, 105.0]);

        $this->assertSame(3, $result['kept']);
        $this->assertSame(105.0, $result['median']);
    }

    #[Test]
    public function it_rejects_a_clear_outlier_using_the_mad(): void
    {
        // Nine sane submissions plus one absurd one.
        $values = [100.0, 102.0, 98.0, 101.0, 99.0, 103.0, 97.0, 100.0, 102.0, 5000.0];

        $result = $this->service->representative($values);

        $this->assertSame(9, $result['kept'], 'the outlier should have been removed');
        $this->assertNotContains(5000.0, $result['filtered']);
        // The mean is no longer dragged upwards by the outlier.
        $this->assertLessThan(110, $result['mean']);
    }

    #[Test]
    public function it_falls_back_to_the_iqr_when_the_mad_cannot_discriminate(): void
    {
        // A tight cluster plus two wild values: MAD is zero because the exact
        // median repeats, so the inter-quartile range has to do the work.
        $values = [100.0, 100.0, 100.0, 100.0, 100.0, 108.0, 92.0, 9000.0, 7000.0];

        $result = $this->service->rejectOutliers($values);

        $this->assertNotContains(9000.0, $result);
        $this->assertNotContains(7000.0, $result);
        $this->assertCount(7, $result);
    }

    #[Test]
    public function it_still_isolates_an_outlier_when_mad_and_iqr_are_both_zero(): void
    {
        // Seven identical submissions and one absurd one: MAD = 0 and IQR = 0,
        // so the mean-absolute-deviation fallback is what catches it.
        $values = [100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 9000.0];

        $result = $this->service->rejectOutliers($values);

        $this->assertNotContains(9000.0, $result);
        $this->assertCount(7, $result);
    }

    #[Test]
    public function it_keeps_everything_when_the_sample_is_too_small(): void
    {
        // Below min_samples_for_filter nothing is discarded, even a wild value:
        // with three submissions we cannot tell noise from a real price.
        $values = [100.0, 110.0, 4000.0];

        $result = $this->service->rejectOutliers($values);

        $this->assertCount(3, $result);
        $this->assertContains(4000.0, $result);
    }

    #[Test]
    public function it_never_returns_an_empty_set_when_input_was_not_empty(): void
    {
        // Identical values: MAD = 0 and IQR = 0, and the guard must still
        // return the original sample rather than nothing at all.
        $values = array_fill(0, 8, 250.0);

        $result = $this->service->representative($values);

        $this->assertSame(8, $result['kept']);
        $this->assertSame(250.0, $result['median']);
        $this->assertSame(250.0, $result['mean']);
    }

    #[Test]
    public function the_configured_threshold_changes_what_is_rejected(): void
    {
        $values = [100.0, 101.0, 99.0, 102.0, 98.0, 100.0, 130.0];

        config()->set('waffir.pricing.mad_threshold', 100.0);
        $this->assertCount(7, $this->service->rejectOutliers($values));

        config()->set('waffir.pricing.mad_threshold', 3.5);
        $this->assertCount(6, $this->service->rejectOutliers($values));
    }
}
