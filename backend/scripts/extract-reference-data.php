<?php

/**
 * One-off generator: reads the academic schema dump (schema.txt at the repo
 * root) and emits database/seeders/data/reference.php so the Arabic reference
 * data used by the seeders is byte-identical to the thesis data set.
 *
 * Run with:  php scripts/extract-reference-data.php
 */

$source = __DIR__.'/../../schema.txt';
$target = __DIR__.'/../database/seeders/data/reference.php';

if (! is_file($source)) {
    fwrite(STDERR, "schema.txt not found at {$source}\n");
    exit(1);
}

$sql = file_get_contents($source);

/** Returns the raw VALUES block of an INSERT statement. */
function block(string $sql, string $table): string
{
    $pattern = '/INSERT\s+INTO\s+'.$table.'\s*\((.*?)\)\s*VALUES\s*(.*?);/is';

    if (! preg_match($pattern, $sql, $m)) {
        fwrite(STDERR, "No INSERT found for {$table}\n");
        exit(1);
    }

    return $m[2];
}

/**
 * Splits a VALUES block into the raw text of each row.
 *
 * A regex is not enough: values such as "قطاع حلب الغربية (الراقي)" contain
 * parentheses inside a string literal, so quoting has to be tracked.
 *
 * @return list<string>
 */
function rawRows(string $values): array
{
    $rows = [];
    $current = '';
    $depth = 0;
    $inString = false;
    $length = mb_strlen($values);

    for ($i = 0; $i < $length; $i++) {
        $char = mb_substr($values, $i, 1);

        if ($char === "'") {
            if ($inString && mb_substr($values, $i + 1, 1) === "'") {
                $current .= "''";
                $i++;

                continue;
            }

            $inString = ! $inString;
            $current .= $char;

            continue;
        }

        if (! $inString && $char === '(') {
            $depth++;

            if ($depth === 1) {
                $current = '';

                continue;
            }
        }

        if (! $inString && $char === ')') {
            $depth--;

            if ($depth === 0) {
                $rows[] = $current;
                $current = '';

                continue;
            }
        }

        if ($depth > 0) {
            $current .= $char;
        }
    }

    return $rows;
}

/** Splits a VALUES block into rows of scalar PHP values. */
function rows(string $values): array
{
    $rows = [];

    foreach (rawRows($values) as $row) {
        $fields = [];
        $current = '';
        $inString = false;
        $length = mb_strlen($row);

        for ($i = 0; $i < $length; $i++) {
            $char = mb_substr($row, $i, 1);

            if ($char === "'") {
                // '' inside a string literal is an escaped quote.
                if ($inString && mb_substr($row, $i + 1, 1) === "'") {
                    $current .= "'";
                    $i++;

                    continue;
                }

                $inString = ! $inString;

                continue;
            }

            if ($char === ',' && ! $inString) {
                $fields[] = trim($current);
                $current = '';

                continue;
            }

            $current .= $char;
        }

        $fields[] = trim($current);

        $rows[] = array_map(static function (string $f) {
            if (strcasecmp($f, 'NULL') === 0) {
                return null;
            }

            if (strcasecmp($f, 'TRUE') === 0) {
                return true;
            }

            if (strcasecmp($f, 'FALSE') === 0) {
                return false;
            }

            if (is_numeric($f)) {
                return $f + 0;
            }

            return $f;
        }, $fields);
    }

    return $rows;
}

$data = [
    'brands' => array_map(static fn (array $r): string => (string) $r[0], rows(block($sql, 'Brand'))),
    'units' => array_map(static fn (array $r): string => (string) $r[0], rows(block($sql, 'Unit'))),
    'products' => array_map(
        static fn (array $r): array => ['name' => (string) $r[0], 'category' => (string) $r[1]],
        rows(block($sql, 'Product')),
    ),
    'sectors' => array_map(
        static fn (array $r): array => ['name' => (string) $r[0], 'description' => (string) $r[1]],
        rows(block($sql, 'Sector')),
    ),
    'locations' => array_map(
        static fn (array $r): array => ['sector' => (int) $r[0], 'district' => (string) $r[1]],
        rows(block($sql, 'Location')),
    ),
    'stores' => array_map(
        static fn (array $r): array => [
            'location' => (int) $r[0],
            'name' => (string) $r[1],
            'address' => (string) $r[2],
            'is_verified' => (bool) $r[3],
        ],
        rows(block($sql, 'Store')),
    ),
    'official_prices' => array_map(
        static fn (array $r): array => [
            'product' => (int) $r[0],
            'unit' => (int) $r[1],
            'amount' => (float) $r[2],
            'price' => (float) $r[3],
        ],
        rows(block($sql, 'OfficialPrice')),
    ),
];

@mkdir(dirname($target), 0777, true);

$export = var_export($data, true);

file_put_contents($target, <<<PHP
<?php

/**
 * GENERATED FILE - do not edit by hand.
 *
 * Produced by scripts/extract-reference-data.php from the thesis schema dump
 * (schema.txt). Indices inside `locations`, `stores` and `official_prices`
 * refer to the 1-based position of the parent row in this same file, exactly
 * as the original dump did.
 */

return {$export};

PHP);

printf(
    "Wrote %s\n  sectors: %d\n  locations: %d\n  units: %d\n  brands: %d\n  products: %d\n  stores: %d\n  official prices: %d\n",
    $target,
    count($data['sectors']),
    count($data['locations']),
    count($data['units']),
    count($data['brands']),
    count($data['products']),
    count($data['stores']),
    count($data['official_prices']),
);
