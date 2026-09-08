<?php

namespace Tests\Feature;

use App\Models\AuthOtp;
use App\Models\Location;
use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Registration, OTP verification, login, refresh rotation and password
 * recovery. Runs against PostgreSQL like every other database test.
 */
class AuthTest extends TestCase
{
    use RefreshDatabase;

    private const OTP = '123456';

    #[Test]
    public function registration_creates_an_unverified_account_and_issues_no_tokens(): void
    {
        $location = Location::factory()->create();

        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Tester',
            'phone_number' => '0991112233',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'location_id' => (string) $location->id,
        ]);

        $response->assertCreated()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.requires_verification', true)
            ->assertJsonPath('data.phone_number', '0991112233')
            ->assertJsonMissingPath('data.access_token');

        $user = User::where('phone_number', '0991112233')->firstOrFail();

        $this->assertNull($user->phone_verified_at);
        $this->assertSame(User::ROLE_USER, $user->role);
        $this->assertDatabaseHas('auth_otps', [
            'phone_number' => '0991112233',
            'purpose' => AuthOtp::PURPOSE_REGISTRATION,
            'is_used' => false,
        ]);
    }

    #[Test]
    public function the_otp_is_never_stored_in_plaintext(): void
    {
        $this->registerUser('0991112233');

        $otp = AuthOtp::where('phone_number', '0991112233')->firstOrFail();

        $this->assertNotSame(self::OTP, $otp->otp_hash);
        $this->assertTrue(Hash::check(self::OTP, $otp->otp_hash));
    }

    #[Test]
    public function a_duplicate_phone_number_is_rejected(): void
    {
        User::factory()->create(['phone_number' => '0991112233']);

        $this->postJson('/api/v1/auth/register', [
            'name' => 'Tester',
            'phone_number' => '0991112233',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ])->assertStatus(422)
            ->assertJsonPath('success', false)
            ->assertJsonStructure(['errors' => ['phone_number']]);
    }

    #[Test]
    public function verifying_the_otp_activates_the_account_and_issues_tokens(): void
    {
        $this->registerUser('0991112233');

        $response = $this->postJson('/api/v1/auth/verify-otp', [
            'phone_number' => '0991112233',
            'code' => self::OTP,
        ]);

        $response->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token', 'user']]);

        $this->assertNotNull(User::where('phone_number', '0991112233')->first()->phone_verified_at);
    }

    #[Test]
    public function an_incorrect_otp_is_rejected_and_counts_as_an_attempt(): void
    {
        $this->registerUser('0991112233');

        $this->postJson('/api/v1/auth/verify-otp', [
            'phone_number' => '0991112233',
            'code' => '000000',
        ])->assertStatus(422)->assertJsonPath('success', false);

        $this->assertSame(1, AuthOtp::where('phone_number', '0991112233')->first()->attempts);
        $this->assertNull(User::where('phone_number', '0991112233')->first()->phone_verified_at);
    }

    #[Test]
    public function an_expired_otp_is_rejected(): void
    {
        $this->registerUser('0991112233');

        AuthOtp::where('phone_number', '0991112233')
            ->update(['expires_at' => Carbon::now()->subMinute()]);

        $this->postJson('/api/v1/auth/verify-otp', [
            'phone_number' => '0991112233',
            'code' => self::OTP,
        ])->assertStatus(422)->assertJsonPath('success', false);

        $this->assertNull(User::where('phone_number', '0991112233')->first()->phone_verified_at);
    }

    #[Test]
    public function login_returns_a_token_pair(): void
    {
        User::factory()->create([
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ]);

        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->assertOk()
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token', 'user']])
            ->assertJsonPath('data.user.role', 0);
    }

    #[Test]
    public function login_with_a_wrong_password_fails(): void
    {
        User::factory()->create(['phone_number' => '0990000001']);

        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'wrong-password',
        ])->assertStatus(401)->assertJsonPath('success', false);
    }

    #[Test]
    public function an_unverified_account_cannot_log_in(): void
    {
        User::factory()->unverified()->create(['phone_number' => '0990000001']);

        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->assertStatus(403)->assertJsonPath('success', false);
    }

    #[Test]
    public function a_blocked_account_cannot_log_in(): void
    {
        User::factory()->blocked()->create(['phone_number' => '0990000001']);

        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->assertStatus(403)->assertJsonPath('success', false);
    }

    #[Test]
    public function a_blocked_account_loses_access_with_an_existing_token(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('t')->plainTextToken;

        $user->update(['is_active' => false]);

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(403)
            ->assertJsonPath('success', false);
    }

    #[Test]
    public function an_admin_can_use_the_admin_login_with_email_or_phone(): void
    {
        $admin = User::factory()->admin()->create(['phone_number' => '0990000002']);

        $this->postJson('/api/v1/auth/admin/login', [
            'username' => $admin->email,
            'password' => 'Password123!',
        ])->assertOk()->assertJsonPath('data.user.role', 1);

        $this->postJson('/api/v1/auth/admin/login', [
            'username' => '0990000002',
            'password' => 'Password123!',
        ])->assertOk()->assertJsonPath('data.user.role', 1);
    }

    #[Test]
    public function a_normal_user_cannot_use_the_admin_login(): void
    {
        User::factory()->create(['phone_number' => '0990000001']);

        $this->postJson('/api/v1/auth/admin/login', [
            'username' => '0990000001',
            'password' => 'Password123!',
        ])->assertStatus(403)->assertJsonPath('success', false);
    }

    #[Test]
    public function refreshing_rotates_the_refresh_token(): void
    {
        $user = User::factory()->create(['phone_number' => '0990000001']);

        $login = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->json('data');

        $refreshed = $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $login['refresh_token'],
        ]);

        $refreshed->assertOk()
            ->assertJsonStructure(['data' => ['access_token', 'refresh_token']]);

        $this->assertNotSame($login['refresh_token'], $refreshed->json('data.refresh_token'));

        // The presented token is dead the moment it is used.
        $this->postJson('/api/v1/auth/refresh', [
            'refresh_token' => $login['refresh_token'],
        ])->assertStatus(401);

        $this->assertSame(
            1,
            RefreshToken::where('user_id', $user->id)->whereNull('revoked_at')->count(),
        );
    }

    #[Test]
    public function refresh_tokens_are_stored_hashed(): void
    {
        User::factory()->create(['phone_number' => '0990000001']);

        $login = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->json('data');

        $this->assertDatabaseMissing('refresh_tokens', [
            'token_hash' => $login['refresh_token'],
        ]);

        $this->assertDatabaseHas('refresh_tokens', [
            'token_hash' => hash('sha256', $login['refresh_token']),
        ]);
    }

    #[Test]
    public function me_returns_everything_needed_to_restore_a_session(): void
    {
        $location = Location::factory()->create();
        $user = User::factory()->create(['location_id' => $location->id]);

        $this->actingAs($user)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', (string) $user->id)
            ->assertJsonPath('data.location_id', (string) $location->id)
            ->assertJsonPath('data.role', 0)
            ->assertJsonPath('data.is_active', true)
            ->assertJsonStructure([
                'data' => [
                    'id', 'name', 'phone_number', 'email', 'role', 'location_id',
                    'location', 'is_active', 'created_at',
                    'prices_count', 'ratings_count', 'reports_count',
                ],
            ]);
    }

    #[Test]
    public function logout_kills_the_access_token(): void
    {
        $user = User::factory()->create(['phone_number' => '0990000001']);

        $token = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->json('data.access_token');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();

        // The auth guard caches the resolved user for the lifetime of the test
        // application, so it has to be reset before asserting on the next
        // request - otherwise we would be testing the cache, not the token.
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertStatus(401);
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    #[Test]
    public function the_profile_endpoint_updates_the_name_and_the_account_location(): void
    {
        $user = User::factory()->create();
        $location = Location::factory()->create();

        $this->actingAs($user)->putJson('/api/v1/auth/profile', [
            'name' => 'New Name',
            'location_id' => (string) $location->id,
        ])->assertOk()
            ->assertJsonPath('data.name', 'New Name')
            ->assertJsonPath('data.location_id', (string) $location->id);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'New Name',
            'location_id' => $location->id,
        ]);
    }

    #[Test]
    public function a_password_can_be_reset_with_an_otp_and_every_session_is_revoked(): void
    {
        $user = User::factory()->create(['phone_number' => '0990000001']);

        $oldToken = $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'Password123!',
        ])->json('data.access_token');

        $this->postJson('/api/v1/auth/forgot-password', [
            'phone_number' => '0990000001',
        ])->assertOk();

        $this->putJson('/api/v1/auth/reset-password', [
            'phone_number' => '0990000001',
            'code' => self::OTP,
            'new_password' => 'BrandNew123!',
            'new_password_confirmation' => 'BrandNew123!',
        ])->assertOk()->assertJsonPath('success', true);

        // The old session is gone.
        $this->withToken($oldToken)->getJson('/api/v1/auth/me')->assertStatus(401);

        // And the new password works.
        $this->postJson('/api/v1/auth/login', [
            'phone_number' => '0990000001',
            'password' => 'BrandNew123!',
        ])->assertOk();

        $this->assertTrue(Hash::check('BrandNew123!', $user->fresh()->password));
    }

    #[Test]
    public function changing_the_password_from_settings_uses_an_otp(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->postJson('/api/v1/auth/change-password/request-otp')
            ->assertOk();

        $this->assertDatabaseHas('auth_otps', [
            'phone_number' => $user->phone_number,
            'purpose' => AuthOtp::PURPOSE_PASSWORD_CHANGE,
        ]);

        $this->actingAs($user)->putJson('/api/v1/auth/change-password', [
            'code' => self::OTP,
            'new_password' => 'BrandNew123!',
            'new_password_confirmation' => 'BrandNew123!',
        ])->assertOk();

        $this->assertTrue(Hash::check('BrandNew123!', $user->fresh()->password));
    }

    private function registerUser(string $phone): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Tester',
            'phone_number' => $phone,
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ])->assertCreated();
    }
}
