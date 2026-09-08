<?php

namespace Database\Seeders;

use App\Models\Location;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

/**
 * DEVELOPMENT ONLY accounts.
 *
 * These credentials exist so the app can be demonstrated end to end. They must
 * never be seeded into a production database.
 */
class DevAccountsSeeder extends Seeder
{
    public const PASSWORD = 'Password123!';

    public function run(): void
    {
        $locations = Location::orderBy('id')->pluck('id')->all();

        $pick = static fn (int $i): int => $locations[$i % count($locations)];

        $accounts = [
            [
                'name' => 'مستخدم وفّر',
                'phone_number' => '0990000001',
                'email' => null,
                'role' => User::ROLE_USER,
                'location_id' => $pick(17),
            ],
            [
                'name' => 'مسؤول وفّر',
                'phone_number' => '0990000002',
                'email' => 'admin@waffir.local',
                'role' => User::ROLE_ADMIN,
                'location_id' => $pick(3),
            ],
            [
                'name' => 'المسؤول الرئيسي',
                'phone_number' => '0990000003',
                'email' => 'superadmin@waffir.local',
                'role' => User::ROLE_SUPER_ADMIN,
                'location_id' => null,
            ],
        ];

        // A few ordinary contributors so submitted prices are not all authored
        // by the same person.
        $contributors = [
            ['name' => 'أحمد', 'phone_number' => '0949749385', 'location_id' => $pick(17)],
            ['name' => 'زكريا', 'phone_number' => '0959997377', 'location_id' => $pick(3)],
            ['name' => 'محمد', 'phone_number' => '0997256925', 'location_id' => $pick(64)],
            ['name' => 'ليلى', 'phone_number' => '0955112233', 'location_id' => $pick(92)],
            ['name' => 'سامر', 'phone_number' => '0933445566', 'location_id' => $pick(76)],
            ['name' => 'ريم', 'phone_number' => '0966778899', 'location_id' => $pick(45)],
        ];

        foreach ($accounts as $account) {
            User::updateOrCreate(
                ['phone_number' => $account['phone_number']],
                array_merge($account, [
                    'password' => self::PASSWORD,
                    'is_active' => true,
                    'phone_verified_at' => Carbon::now(),
                ]),
            );
        }

        foreach ($contributors as $contributor) {
            User::updateOrCreate(
                ['phone_number' => $contributor['phone_number']],
                array_merge($contributor, [
                    'email' => null,
                    'role' => User::ROLE_USER,
                    'password' => self::PASSWORD,
                    'is_active' => true,
                    'phone_verified_at' => Carbon::now(),
                ]),
            );
        }
    }
}
