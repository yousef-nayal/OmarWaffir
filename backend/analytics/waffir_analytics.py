"""Representative real-price algorithm - reference implementation in Python.

The production path is the PHP service (app/Services/PriceAggregationService.php)
so that serving an HTTP request never depends on spawning a Python process.
This module exists for:

  * offline analysis of an exported price data set
  * reproducing the thesis numbers outside the application
  * cross-checking the PHP implementation (see compare_with_php.py)
  * building more advanced analytics later

It has no third-party dependencies: the standard library is enough.

Usage:

    python -m waffir_analytics --help
    python waffir_analytics.py --demo
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from dataclasses import dataclass, field
from typing import Iterable, Sequence

# Defaults mirror config/waffir.php -> 'pricing'.
DEFAULT_MAD_THRESHOLD = 3.5
DEFAULT_MIN_SAMPLES_FOR_FILTER = 5
DEFAULT_IQR_MULTIPLIER = 1.5

# 0.6745 makes the MAD a consistent estimator of sigma for normally
# distributed data; 1.253314 does the same for the mean absolute deviation
# (Iglewicz and Hoaglin, "How to Detect and Handle Outliers").
MAD_SCALE = 0.6745
MEAN_AD_SCALE = 1.253314


@dataclass(frozen=True)
class PricingConfig:
    """Every threshold the algorithm uses, so experiments stay reproducible."""

    mad_threshold: float = DEFAULT_MAD_THRESHOLD
    min_samples_for_filter: int = DEFAULT_MIN_SAMPLES_FOR_FILTER
    iqr_multiplier: float = DEFAULT_IQR_MULTIPLIER


@dataclass(frozen=True)
class Representative:
    """The outcome of aggregating one product in one location."""

    median: float
    mean: float
    kept: list[float] = field(default_factory=list)
    rejected: list[float] = field(default_factory=list)

    @property
    def sample_size(self) -> int:
        return len(self.kept)


def normalise(prices: Iterable[tuple[float, float]]) -> list[float]:
    """Turn (price, amount) submissions into prices for a single unit.

    Rows with a non-positive amount or price are dropped: they cannot describe
    a real purchase.
    """
    values: list[float] = []
    for price, amount in prices:
        if amount is None or price is None:
            continue
        if amount <= 0 or price <= 0:
            continue
        values.append(float(price) / float(amount))
    return values


def median(values: Sequence[float]) -> float:
    return float(statistics.median(values)) if values else 0.0


def _percentile(sorted_values: Sequence[float], p: float) -> float:
    if not sorted_values:
        return 0.0
    index = (len(sorted_values) - 1) * p
    lower = int(index)
    upper = min(lower + 1, len(sorted_values) - 1)
    if lower == upper:
        return float(sorted_values[lower])
    weight = index - lower
    return float(sorted_values[lower] + weight * (sorted_values[upper] - sorted_values[lower]))


def reject_outliers(
    values: Sequence[float],
    config: PricingConfig | None = None,
) -> tuple[list[float], list[float]]:
    """Split values into (kept, rejected).

    Strategy, in order:
      1. too few samples -> keep everything, filtering would be guesswork
      2. modified z-score based on the median absolute deviation
      3. inter-quartile range, when the MAD is zero
      4. mean absolute deviation, when the IQR is zero as well
    """
    config = config or PricingConfig()
    values = [float(v) for v in values if v is not None and v > 0]

    if len(values) < config.min_samples_for_filter:
        return list(values), []

    med = median(values)
    deviations = [abs(v - med) for v in values]
    mad = median(deviations)

    if mad > 0:
        kept = [v for v in values if abs(MAD_SCALE * (v - med) / mad) <= config.mad_threshold]
        if kept:
            return kept, [v for v in values if v not in kept]
        return list(values), []

    ordered = sorted(values)
    q1 = _percentile(ordered, 0.25)
    q3 = _percentile(ordered, 0.75)
    iqr = q3 - q1

    if iqr > 0:
        low = q1 - config.iqr_multiplier * iqr
        high = q3 + config.iqr_multiplier * iqr
        kept = [v for v in values if low <= v <= high]
        if kept and len(kept) < len(values):
            return kept, [v for v in values if v < low or v > high]

    mean_ad = sum(abs(v - med) for v in values) / len(values)
    if mean_ad > 0:
        kept = [
            v for v in values
            if abs((v - med) / (MEAN_AD_SCALE * mean_ad)) <= config.mad_threshold
        ]
        if kept:
            return kept, [v for v in values if v not in kept]

    return list(values), []


def representative(
    values: Sequence[float],
    config: PricingConfig | None = None,
) -> Representative:
    """Median and mean of the submissions that survive outlier rejection."""
    values = [float(v) for v in values if v is not None and v > 0]

    if not values:
        return Representative(median=0.0, mean=0.0, kept=[], rejected=[])

    kept, rejected = reject_outliers(values, config)

    return Representative(
        median=median(kept),
        mean=sum(kept) / len(kept),
        kept=kept,
        rejected=rejected,
    )


def aggregate_product(
    submissions: Sequence[tuple[float, float]],
    official_price: float,
    official_amount: float = 1.0,
    config: PricingConfig | None = None,
) -> dict[str, float | bool | int]:
    """Full per-product projection, matching the /products API response.

    `submissions` is a sequence of (price, amount) rows already restricted to
    one product, one unit and (optionally) one location.
    """
    stats = representative(normalise(submissions), config)

    real_price = round(stats.median * official_amount, 2)
    avg_price = round(stats.mean * official_amount, 2)
    official_price = round(float(official_price), 2)

    change_percent = 0.0
    if official_price > 0 and real_price > 0:
        change_percent = round((real_price - official_price) / official_price * 100, 2)

    return {
        "official_price": official_price,
        "real_price": real_price,
        "avg_price": avg_price,
        "amount": float(official_amount),
        "prices_count": len(submissions),
        "kept_samples": stats.sample_size,
        "change_percent": change_percent,
        "is_price_up": real_price >= official_price,
    }


def _demo() -> None:
    submissions = [
        (110.0, 1.0),
        (125.0, 1.0),
        (105.0, 1.0),
        (220.0, 2.0),   # same unit price as 110
        (112.0, 1.0),
        (108.0, 1.0),
        (5000.0, 1.0),  # an obvious outlier
    ]

    result = aggregate_product(submissions, official_price=110, official_amount=1)
    print(json.dumps(result, indent=2, ensure_ascii=False))


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--demo", action="store_true", help="run a small worked example")
    parser.add_argument(
        "--json",
        help='aggregate a JSON file: {"official_price": 110, "official_amount": 1, '
             '"submissions": [[price, amount], ...]}',
    )
    args = parser.parse_args(argv)

    if args.json:
        with open(args.json, encoding="utf-8") as handle:
            payload = json.load(handle)
        result = aggregate_product(
            [tuple(row) for row in payload["submissions"]],
            official_price=payload.get("official_price", 0),
            official_amount=payload.get("official_amount", 1),
        )
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    if args.demo:
        _demo()
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
