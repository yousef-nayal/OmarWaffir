<?php

namespace Database\Factories;

use App\Models\Sector;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Sector> */
class SectorFactory extends Factory
{
    protected $model = Sector::class;

    public function definition(): array
    {
        return [
            'name' => 'Sector '.fake()->unique()->numberBetween(1, 100000),
            'description' => fake()->sentence(),
        ];
    }
}
