"""Tests for the Python reference implementation.

Run with the standard library only:

    python -m unittest discover -s analytics -p "test_*.py"

These mirror tests/Unit/PriceAggregationServiceTest.php so the two
implementations can be compared case by case.
"""

from __future__ import annotations

import os
import sys
import unittest

# Make the module importable no matter which directory the tests are run from
# (and under an embeddable Python, where the script directory is not on the
# path automatically).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from waffir_analytics import (  # noqa: E402
    PricingConfig,
    aggregate_product,
    median,
    normalise,
    reject_outliers,
    representative,
)


class NormaliseTests(unittest.TestCase):
    def test_it_divides_price_by_amount(self):
        self.assertEqual(normalise([(220.0, 2.0), (110.0, 1.0)]), [110.0, 110.0])

    def test_it_drops_impossible_rows(self):
        self.assertEqual(normalise([(100.0, 0.0), (-5.0, 1.0), (50.0, 1.0)]), [50.0])


class MedianTests(unittest.TestCase):
    def test_odd_sample(self):
        self.assertEqual(median([90.0, 100.0, 130.0]), 100.0)

    def test_even_sample(self):
        self.assertEqual(median([90.0, 100.0, 110.0, 130.0]), 105.0)

    def test_empty_sample(self):
        self.assertEqual(median([]), 0.0)


class OutlierTests(unittest.TestCase):
    def test_mad_rejects_a_clear_outlier(self):
        values = [100.0, 102.0, 98.0, 101.0, 99.0, 103.0, 97.0, 100.0, 102.0, 5000.0]

        kept, rejected = reject_outliers(values)

        self.assertNotIn(5000.0, kept)
        self.assertIn(5000.0, rejected)
        self.assertEqual(len(kept), 9)

    def test_a_small_sample_is_never_filtered(self):
        values = [100.0, 110.0, 4000.0]

        kept, rejected = reject_outliers(values)

        self.assertEqual(kept, values)
        self.assertEqual(rejected, [])

    def test_iqr_fallback_when_mad_is_zero(self):
        values = [100.0, 100.0, 100.0, 100.0, 100.0, 108.0, 92.0, 9000.0, 7000.0]

        kept, _ = reject_outliers(values)

        self.assertNotIn(9000.0, kept)
        self.assertNotIn(7000.0, kept)
        self.assertEqual(len(kept), 7)

    def test_mean_ad_fallback_when_mad_and_iqr_are_zero(self):
        values = [100.0] * 7 + [9000.0]

        kept, _ = reject_outliers(values)

        self.assertNotIn(9000.0, kept)
        self.assertEqual(len(kept), 7)

    def test_identical_values_are_all_kept(self):
        values = [250.0] * 8

        kept, rejected = reject_outliers(values)

        self.assertEqual(len(kept), 8)
        self.assertEqual(rejected, [])

    def test_the_threshold_is_configurable(self):
        values = [100.0, 101.0, 99.0, 102.0, 98.0, 100.0, 130.0]

        loose, _ = reject_outliers(values, PricingConfig(mad_threshold=100.0))
        strict, _ = reject_outliers(values, PricingConfig(mad_threshold=3.5))

        self.assertEqual(len(loose), 7)
        self.assertEqual(len(strict), 6)


class RepresentativeTests(unittest.TestCase):
    def test_no_values(self):
        result = representative([])

        self.assertEqual(result.median, 0.0)
        self.assertEqual(result.mean, 0.0)
        self.assertEqual(result.sample_size, 0)

    def test_non_positive_values_are_dropped(self):
        result = representative([100.0, -50.0, 0.0, 110.0, 105.0])

        self.assertEqual(result.sample_size, 3)
        self.assertEqual(result.median, 105.0)


class AggregateProductTests(unittest.TestCase):
    def test_amount_normalisation_and_change_percent(self):
        result = aggregate_product(
            [(100.0, 1.0), (200.0, 2.0)],
            official_price=100,
            official_amount=1,
        )

        self.assertEqual(result["real_price"], 100.0)
        self.assertEqual(result["avg_price"], 100.0)
        self.assertEqual(result["change_percent"], 0.0)
        self.assertTrue(result["is_price_up"])

    def test_a_market_above_the_official_price(self):
        result = aggregate_product(
            [(180.0, 1.0), (182.0, 1.0), (184.0, 1.0)],
            official_price=100,
            official_amount=1,
        )

        self.assertEqual(result["real_price"], 182.0)
        self.assertEqual(result["change_percent"], 82.0)
        self.assertTrue(result["is_price_up"])

    def test_no_market_data(self):
        result = aggregate_product([], official_price=100, official_amount=1)

        self.assertEqual(result["real_price"], 0.0)
        self.assertEqual(result["avg_price"], 0.0)
        self.assertEqual(result["change_percent"], 0.0)
        self.assertEqual(result["prices_count"], 0)

    def test_the_official_amount_scales_the_result(self):
        # Official price is for 2 units; submissions are per single unit.
        result = aggregate_product(
            [(50.0, 1.0), (52.0, 1.0), (48.0, 1.0)],
            official_price=100,
            official_amount=2,
        )

        self.assertEqual(result["real_price"], 100.0)


if __name__ == "__main__":
    unittest.main()
