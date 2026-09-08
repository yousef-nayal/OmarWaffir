<?php

namespace Database\Factories;

use App\Models\OfficialPrice;
use App\Models\Product;
use App\Models\Unit;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/** @extends Factory<OfficialPrice> */
class OfficialPriceFactory extends Factory
{
    protected $model = OfficialPrice::class;

    public function definition(): array
    {
        return [
            'product_id' => Product::factory(),
            'unit_id' => Unit::factory(),
            'amount' => 1,
            'price' => fake()->numberBetween(50, 500),
            'created_by' => null,
            'created_at' => Carbon::now(),
        ];
    }
}
