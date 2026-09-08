<?php

namespace Database\Factories;

use App\Models\Location;
use App\Models\Sector;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Location> */
class LocationFactory extends Factory
{
    protected $model = Location::class;

    public function definition(): array
    {
        return [
            'sector_id' => Sector::factory(),
            'district' => 'District '.fake()->unique()->numberBetween(1, 100000),
        ];
    }
}
