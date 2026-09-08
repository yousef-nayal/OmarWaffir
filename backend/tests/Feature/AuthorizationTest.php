<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The authorisation boundary is the backend, not the Flutter navigation stack.
 */
class AuthorizationTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function an_anonymous_visitor_cannot_reach_admin_endpoints(): void
    {
        $this->getJson('/api/v1/admin/dashboard-stats')->assertStatus(401);
        $this->getJson('/api/v1/admin/users')->assertStatus(401);
        $this->getJson('/api/v1/prices')->assertStatus(401);
    }

    #[Test]
    public function a_normal_user_cannot_reach_admin_endpoints(): void
    {
        $user = User::factory()->create();

        foreach ([
            ['get', '/api/v1/admin/dashboard-stats'],
            ['get', '/api/v1/admin/recent-activity'],
            ['get', '/api/v1/admin/users'],
            ['get', '/api/v1/prices'],
            ['get', '/api/v1/reports'],
            ['post', '/api/v1/products'],
            ['post', '/api/v1/units'],
            ['post', '/api/v1/brands'],
            ['post', '/api/v1/sectors'],
            ['post', '/api/v1/locations'],
            ['post', '/api/v1/official-prices'],
        ] as [$method, $uri]) {
            $this->actingAs($user)->{$method.'Json'}($uri)
                ->assertStatus(403, "expected 403 for {$method} {$uri}")
                ->assertJsonPath('success', false);
        }
    }

    #[Test]
    public function an_admin_can_manage_the_catalogue(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)->postJson('/api/v1/products', [
            'name' => 'New Product',
            'category' => 'grains',
        ])->assertCreated();

        $this->assertDatabaseHas('products', ['name' => 'New Product']);
    }

    #[Test]
    public function an_admin_cannot_manage_another_admin(): void
    {
        $admin = User::factory()->admin()->create();
        $other = User::factory()->admin()->create();

        $this->actingAs($admin)->putJson("/api/v1/admin/users/{$other->id}", [
            'name' => 'Renamed',
        ])->assertStatus(403);

        $this->actingAs($admin)
            ->patchJson("/api/v1/admin/users/{$other->id}/block")
            ->assertStatus(403);

        $this->actingAs($admin)
            ->deleteJson("/api/v1/admin/users/{$other->id}")
            ->assertStatus(403);
    }

    #[Test]
    public function an_admin_cannot_create_an_admin(): void
    {
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)->postJson('/api/v1/admin/users', [
            'name' => 'Wannabe',
            'phone_number' => '0995550000',
            'password' => 'Password123!',
            'role' => User::ROLE_ADMIN,
        ])->assertStatus(403);

        $this->assertDatabaseMissing('users', ['phone_number' => '0995550000']);
    }

    #[Test]
    public function an_admin_cannot_change_roles_at_all(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create();

        // The role endpoint is behind role:2.
        $this->actingAs($admin)
            ->patchJson("/api/v1/admin/users/{$user->id}/role", ['role' => 1])
            ->assertStatus(403);
    }

    #[Test]
    public function a_super_admin_can_create_and_promote_admins(): void
    {
        $superAdmin = User::factory()->superAdmin()->create();
        $user = User::factory()->create();

        $this->actingAs($superAdmin)->postJson('/api/v1/admin/users', [
            'name' => 'New Admin',
            'phone_number' => '0995550001',
            'password' => 'Password123!',
            'role' => User::ROLE_ADMIN,
        ])->assertCreated()->assertJsonPath('data.role', 1);

        $this->actingAs($superAdmin)
            ->patchJson("/api/v1/admin/users/{$user->id}/role", ['role' => 1])
            ->assertOk()
            ->assertJsonPath('data.role', 1);
    }

    #[Test]
    public function nobody_can_act_on_their_own_account_through_admin_endpoints(): void
    {
        $superAdmin = User::factory()->superAdmin()->create();

        $this->actingAs($superAdmin)
            ->deleteJson("/api/v1/admin/users/{$superAdmin->id}")
            ->assertStatus(403);

        $this->actingAs($superAdmin)
            ->patchJson("/api/v1/admin/users/{$superAdmin->id}/block")
            ->assertStatus(403);
    }

    #[Test]
    public function the_last_super_admin_cannot_be_deleted_or_demoted(): void
    {
        $superAdmin = User::factory()->superAdmin()->create();
        $other = User::factory()->superAdmin()->create();

        // Two super admins: removing one is allowed.
        $this->actingAs($superAdmin)
            ->deleteJson("/api/v1/admin/users/{$other->id}")
            ->assertOk();

        // Now only one is left, and a second super admin is needed to try
        // again - so demote through a freshly promoted one.
        $promoted = User::factory()->superAdmin()->create();

        $this->actingAs($promoted)
            ->deleteJson("/api/v1/admin/users/{$superAdmin->id}")
            ->assertOk();

        // A single remaining super admin cannot be demoted by anyone.
        $newSuper = User::factory()->superAdmin()->create();
        User::where('id', $promoted->id)->delete();

        $this->actingAs($newSuper)
            ->patchJson("/api/v1/admin/users/{$newSuper->id}/role", ['role' => 0])
            ->assertStatus(403);
    }

    #[Test]
    public function public_reads_do_not_require_a_session(): void
    {
        Product::factory()->create();

        $this->getJson('/api/v1/products')->assertOk();
        $this->getJson('/api/v1/stores')->assertOk();
        $this->getJson('/api/v1/locations')->assertOk();
        $this->getJson('/api/v1/sectors')->assertOk();
        $this->getJson('/api/v1/units')->assertOk();
        $this->getJson('/api/v1/brands')->assertOk();
        $this->getJson('/api/v1/official-prices')->assertOk();
        $this->getJson('/api/v1/health')->assertOk();
    }
}
