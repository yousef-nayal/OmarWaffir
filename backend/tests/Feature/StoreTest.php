<?php

namespace Tests\Feature;

use App\Models\Location;
use App\Models\Price;
use App\Models\Sector;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class StoreTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_store_submitted_by_a_normal_user_starts_unverified(): void
    {
        $user = User::factory()->create();
        $location = Location::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/stores', [
            'location_id' => (string) $location->id,
            'name' => 'Corner Shop',
            'address' => 'Main street',
            // Even if the client asks for a verified store, it is ignored.
            'is_verified' => true,
        ])->assertCreated()
            ->assertJsonPath('data.is_verified', false)
            ->assertJsonPath('data.location_id', (string) $location->id);

        $this->assertDatabaseHas('stores', [
            'name' => 'Corner Shop',
            'is_verified' => false,
            'submitted_by_user_id' => $user->id,
        ]);
    }

    #[Test]
    public function an_admin_may_create_a_verified_store(): void
    {
        $admin = User::factory()->admin()->create();
        $location = Location::factory()->create();

        $this->actingAs($admin)->postJson('/api/v1/stores', [
            'location_id' => (string) $location->id,
            'name' => 'Official Shop',
            'address' => 'Main street',
            'is_verified' => true,
        ])->assertCreated()->assertJsonPath('data.is_verified', true);
    }

    #[Test]
    public function an_admin_can_verify_a_store(): void
    {
        $admin = User::factory()->admin()->create();
        $store = Store::factory()->unverified()->create();

        $this->actingAs($admin)
            ->patchJson("/api/v1/stores/{$store->id}/verify", ['is_verified' => true])
            ->assertOk()
            ->assertJsonPath('data.is_verified', true);

        $this->assertDatabaseHas('stores', ['id' => $store->id, 'is_verified' => true]);
    }

    #[Test]
    public function a_normal_user_cannot_verify_a_store(): void
    {
        $user = User::factory()->create();
        $store = Store::factory()->unverified()->create();

        $this->actingAs($user)
            ->patchJson("/api/v1/stores/{$store->id}/verify", ['is_verified' => true])
            ->assertStatus(403);

        $this->assertDatabaseHas('stores', ['id' => $store->id, 'is_verified' => false]);
    }

    #[Test]
    public function stores_can_be_filtered(): void
    {
        $sector = Sector::factory()->create();
        $location = Location::factory()->create(['sector_id' => $sector->id]);

        Store::factory()->create(['name' => 'Alpha Market', 'location_id' => $location->id]);
        Store::factory()->unverified()->create(['name' => 'Beta Market']);
        Store::factory()->create(['name' => 'Gamma Market']);

        $this->getJson('/api/v1/stores?search=Alpha')
            ->assertOk()->assertJsonCount(1, 'data');

        $this->getJson("/api/v1/stores?sector_id={$sector->id}")
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Alpha Market');

        $this->getJson("/api/v1/stores?location_id={$location->id}")
            ->assertOk()->assertJsonCount(1, 'data');

        $this->getJson('/api/v1/stores?is_verified=0')
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Beta Market');
    }

    #[Test]
    public function the_store_payload_carries_the_ids_the_app_needs(): void
    {
        $store = Store::factory()->create();
        Price::factory()->count(2)->create(['store_id' => $store->id]);

        $this->getJson("/api/v1/stores/{$store->id}")
            ->assertOk()
            ->assertJsonPath('data.prices_count', 2)
            ->assertJsonStructure([
                'data' => [
                    'id', 'location_id', 'name', 'address', 'district', 'area',
                    'sector_id', 'sector', 'is_verified', 'prices_count',
                ],
            ]);
    }

    #[Test]
    public function deleting_a_store_deletes_the_prices_submitted_for_it(): void
    {
        $admin = User::factory()->admin()->create();
        $store = Store::factory()->create();
        $price = Price::factory()->create(['store_id' => $store->id]);
        $survivor = Price::factory()->create();

        $this->actingAs($admin)
            ->getJson("/api/v1/admin/deletion-impact/store/{$store->id}")
            ->assertOk()
            ->assertJsonPath('data.prices', 1);

        $this->actingAs($admin)->deleteJson("/api/v1/stores/{$store->id}")->assertOk();

        $this->assertSoftDeleted('stores', ['id' => $store->id]);
        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseHas('prices', ['id' => $survivor->id]);
    }
}
