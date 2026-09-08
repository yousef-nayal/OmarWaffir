<?php

namespace Database\Factories;

use App\Models\Location;
use App\Models\Store;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Store> */
class StoreFactory extends Factory
{
    protected $model = Store::class;

    public function definition(): array
    {
        return [
            'location_id' => Location::factory(),
            'name' => 'Store '.fake()->unique()->numberBetween(1, 100000),
            'address' => fake()->streetAddress(),
            'is_verified' => true,
            'submitted_by_user_id' => null,
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn (): array => ['is_verified' => false]);
    }
}
