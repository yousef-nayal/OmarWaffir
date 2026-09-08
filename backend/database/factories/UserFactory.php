<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Carbon;

/** @extends Factory<User> */
class UserFactory extends Factory
{
    protected $model = User::class;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'phone_number' => '09'.fake()->unique()->numerify('########'),
            'email' => null,
            'password' => 'Password123!',
            'role' => User::ROLE_USER,
            'is_active' => true,
            'phone_verified_at' => Carbon::now(),
            'location_id' => null,
        ];
    }

    public function unverified(): static
    {
        return $this->state(fn (): array => ['phone_verified_at' => null]);
    }

    public function blocked(): static
    {
        return $this->state(fn (): array => ['is_active' => false]);
    }

    public function admin(): static
    {
        return $this->state(fn (): array => [
            'role' => User::ROLE_ADMIN,
            'email' => fake()->unique()->safeEmail(),
        ]);
    }

    public function superAdmin(): static
    {
        return $this->state(fn (): array => [
            'role' => User::ROLE_SUPER_ADMIN,
            'email' => fake()->unique()->safeEmail(),
        ]);
    }
}
