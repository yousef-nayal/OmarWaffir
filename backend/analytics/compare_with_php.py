"""Cross-check the Python reference against the PHP production service.

The two implementations must agree; this script proves it on a set of cases
that includes the awkward ones (outliers, MAD = 0, tiny samples, amount
normalisation).

    python analytics/compare_with_php.py              # uses `php` from PATH
    python analytics/compare_with_php.py --php C:/php/php.exe

Exit code is 0 when every case matches.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from waffir_analytics import aggregate_product  # noqa: E402

BACKEND_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (label, submissions as [price, amount], official price, official amount)
CASES = [
    ("tight cluster", [[110, 1], [112, 1], [108, 1], [111, 1], [109, 1]], 110, 1),
    ("one wild outlier",
     [[100, 1], [102, 1], [98, 1], [101, 1], [99, 1], [103, 1], [97, 1], [100, 1], [102, 1], [5000, 1]],
     100, 1),
    ("mad is zero", [[100, 1]] * 5 + [[108, 1], [92, 1], [9000, 1], [7000, 1]], 100, 1),
    ("mad and iqr are zero", [[100, 1]] * 7 + [[9000, 1]], 100, 1),
    ("tiny sample keeps everything", [[100, 1], [110, 1], [4000, 1]], 100, 1),
    ("amount normalisation", [[100, 1], [200, 2], [300, 3]], 100, 1),
    ("official amount is 2", [[50, 1], [52, 1], [48, 1]], 100, 2),
    ("no submissions", [], 100, 1),
    ("market above official", [[180, 1], [182, 1], [184, 1]], 100, 1),
    ("market below official", [[90, 1], [92, 1], [94, 1]], 100, 1),
]

PHP_DRIVER = r"""
<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$service = new App\Services\PriceAggregationService();
$cases = json_decode(file_get_contents('php://stdin'), true);
$out = [];

foreach ($cases as $case) {
    $values = [];
    foreach ($case['submissions'] as [$price, $amount]) {
        if ($amount > 0 && $price > 0) {
            $values[] = $price / $amount;
        }
    }

    $stats = $service->representative($values);
    $amount = (float) $case['official_amount'];
    $official = round((float) $case['official_price'], 2);
    $real = round($stats['median'] * $amount, 2);
    $avg = round($stats['mean'] * $amount, 2);

    $change = 0.0;
    if ($official > 0 && $real > 0) {
        $change = round((($real - $official) / $official) * 100, 2);
    }

    $out[] = [
        'label' => $case['label'],
        'real_price' => $real,
        'avg_price' => $avg,
        'kept_samples' => $stats['kept'],
        'change_percent' => $change,
        'is_price_up' => $real >= $official,
    ];
}

echo json_encode($out);
"""


def run_php(php_binary: str) -> list[dict]:
    driver_path = os.path.join(BACKEND_ROOT, "_compare_driver.php")

    with open(driver_path, "w", encoding="utf-8") as handle:
        handle.write(PHP_DRIVER)

    payload = json.dumps([
        {
            "label": label,
            "submissions": submissions,
            "official_price": official_price,
            "official_amount": official_amount,
        }
        for label, submissions, official_price, official_amount in CASES
    ])

    try:
        completed = subprocess.run(
            [php_binary, driver_path],
            input=payload,
            capture_output=True,
            text=True,
            cwd=BACKEND_ROOT,
            check=True,
        )
    finally:
        os.remove(driver_path)

    return json.loads(completed.stdout)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--php", default="php", help="path to the php binary")
    args = parser.parse_args()

    try:
        php_results = run_php(args.php)
    except FileNotFoundError:
        print(f"php binary not found: {args.php}")
        return 2
    except subprocess.CalledProcessError as error:
        print("the PHP driver failed:")
        print(error.stderr)
        return 2

    failures = 0
    width = max(len(label) for label, *_ in CASES)

    for (label, submissions, official_price, official_amount), php in zip(CASES, php_results):
        py = aggregate_product(
            [tuple(row) for row in submissions],
            official_price=official_price,
            official_amount=official_amount,
        )

        same = (
            abs(py["real_price"] - php["real_price"]) < 0.01
            and abs(py["avg_price"] - php["avg_price"]) < 0.01
            and py["kept_samples"] == php["kept_samples"]
            and abs(py["change_percent"] - php["change_percent"]) < 0.01
            and py["is_price_up"] == php["is_price_up"]
        )

        status = "OK  " if same else "DIFF"
        if not same:
            failures += 1

        print(
            f"{status} {label.ljust(width)}  "
            f"php real={php['real_price']:<9} py real={py['real_price']:<9} "
            f"kept php={php['kept_samples']} py={py['kept_samples']}"
        )

    print()
    print(f"{len(CASES) - failures}/{len(CASES)} cases match")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
