<?php

namespace Database\Seeders;

use App\Models\Brand;
use App\Models\Location;
use App\Models\Product;
use App\Models\Sector;
use App\Models\Unit;
use Illuminate\Database\Seeder;

/**
 * Sectors, districts, units, brands and products.
 *
 * The Arabic values come from database/seeders/data/reference.php, which is
 * generated from the thesis schema dump so the district names match the ones
 * the Flutter location picker uses.
 */
class ReferenceSeeder extends Seeder
{
    public function run(): void
    {
        $data = require __DIR__.'/data/reference.php';

        foreach ($data['sectors'] as $sector) {
            Sector::updateOrCreate(
                ['name' => $sector['name']],
                ['description' => $sector['description']],
            );
        }

        $sectorIds = Sector::orderBy('id')->pluck('id')->all();

        foreach ($data['locations'] as $location) {
            Location::updateOrCreate([
                'sector_id' => $sectorIds[$location['sector'] - 1],
                'district' => $location['district'],
            ]);
        }

        foreach ($data['units'] as $unit) {
            Unit::updateOrCreate(['name' => $unit]);
        }

        // Extra units the UI offers beyond the three in the thesis dump.
        foreach (['غرام', 'عبوة'] as $unit) {
            Unit::updateOrCreate(['name' => $unit]);
        }

        foreach ($data['brands'] as $brand) {
            Brand::updateOrCreate(['name' => $brand]);
        }

        foreach ($data['products'] as $product) {
            Product::updateOrCreate(
                ['name' => $product['name']],
                ['category' => $product['category']],
            );
        }
    }
}
