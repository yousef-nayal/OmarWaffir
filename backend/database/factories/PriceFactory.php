<?php

namespace Database\Factories;

use App\Models\Brand;
use App\Models\Price;
use App\Models\Product;
use App\Models\Store;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Price> */
class PriceFactory extends Factory
{
    protected $model = Price::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'store_id' => Store::factory(),
            'product_id' => Product::factory(),
            'unit_id' => Unit::factory(),
            'brand_id' => Brand::factory(),
            'amount' => 1,
            'price' => fake()->numberBetween(50, 500),
        ];
    }
}
