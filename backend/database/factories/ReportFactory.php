<?php

namespace Database\Factories;

use App\Models\Price;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Report> */
class ReportFactory extends Factory
{
    protected $model = Report::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'price_id' => Price::factory(),
            'type' => Report::TYPE_OVERPRICED,
            'description' => null,
        ];
    }
}
