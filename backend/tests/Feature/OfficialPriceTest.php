<?php

namespace Tests\Feature;

use App\Models\OfficialPrice;
use App\Models\Product;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class OfficialPriceTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function the_list_shows_only_the_current_version_of_each_series(): void
    {
        $product = Product::factory()->create();
        $unit = Unit::factory()->create();

        OfficialPrice::factory()->create([
            'product_id' => $product->id, 'unit_id' => $unit->id,
            'amount' => 1, 'price' => 100, 'created_at' => Carbon::now()->subDays(10),
        ]);
        OfficialPrice::factory()->create([
            'product_id' => $product->id, 'unit_id' => $unit->id,
            'amount' => 1, 'price' => 150, 'created_at' => Carbon::now(),
        ]);

        $this->getJson('/api/v1/official-prices')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.price', 150);
    }

    #[Test]
    public function updating_inserts_a_new_version_and_keeps_the_old_one(): void
    {
        $admin = User::factory()->admin()->create();
        $product = Product::factory()->create();
        $unit = Unit::factory()->create();

        $original = OfficialPrice::factory()->create([
            'product_id' => $product->id, 'unit_id' => $unit->id,
            'amount' => 1, 'price' => 100,
        ]);

        $this->actingAs($admin)->putJson("/api/v1/official-prices/{$original->id}", [
            'product_id' => (string) $product->id,
            'unit_id' => (string) $unit->id,
            'amount' => 1,
            'price' => 175,
        ])->assertOk()->assertJsonPath('data.price', 175);

        // The original row is untouched.
        $this->assertDatabaseHas('official_prices', [
            'id' => $original->id,
            'price' => 100,
        ]);
        $this->assertSame(2, OfficialPrice::count());
    }

    #[Test]
    public function the_history_endpoint_returns_every_version_newest_first(): void
    {
        $product = Product::factory()->create();
        $unit = Unit::factory()->create();

        foreach ([[100, 20], [130, 10], [160, 1]] as [$price, $daysAgo]) {
            $row = OfficialPrice::factory()->create([
                'product_id' => $product->id, 'unit_id' => $unit->id,
                'amount' => 1, 'price' => $price,
                'created_at' => Carbon::now()->subDays($daysAgo),
            ]);
        }

        $this->getJson("/api/v1/official-prices/{$row->id}/history")
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.price', 160)
            ->assertJsonPath('data.1.price', 130)
            ->assertJsonPath('data.2.price', 100)
            ->assertJsonStructure(['data' => [['id', 'price', 'amount', 'unit', 'changed_at']]]);
    }

    #[Test]
    public function creating_an_official_price_notifies_verified_users(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create();
        User::factory()->unverified()->create();
        User::factory()->blocked()->create();

        $product = Product::factory()->create();
        $unit = Unit::factory()->create();

        $this->actingAs($admin)->postJson('/api/v1/official-prices', [
            'product_id' => (string) $product->id,
            'unit_id' => (string) $unit->id,
            'amount' => 1,
            'price' => 500,
        ])->assertCreated();

        // Only the active, verified, normal user is notified.
        $this->assertSame(1, $user->notifications()->count());
        $this->assertDatabaseCount('notifications', 1);

        $this->actingAs($user)->getJson('/api/v1/notifications')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.type', 'official_price')
            ->assertJsonPath('data.0.is_read', false);
    }

    #[Test]
    public function notifications_can_be_marked_as_read(): void
    {
        $admin = User::factory()->admin()->create();
        $user = User::factory()->create();

        $this->actingAs($admin)->postJson('/api/v1/official-prices', [
            'product_id' => (string) Product::factory()->create()->id,
            'unit_id' => (string) Unit::factory()->create()->id,
            'amount' => 1,
            'price' => 500,
        ])->assertCreated();

        $this->actingAs($user)->getJson('/api/v1/notifications/unread-count')
            ->assertOk()->assertJsonPath('data.unread_count', 1);

        $this->actingAs($user)->patchJson('/api/v1/notifications/read-all')->assertOk();

        $this->actingAs($user)->getJson('/api/v1/notifications/unread-count')
            ->assertOk()->assertJsonPath('data.unread_count', 0);
    }

    #[Test]
    public function a_normal_user_cannot_mutate_official_prices(): void
    {
        $user = User::factory()->create();
        $official = OfficialPrice::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/official-prices', [
            'product_id' => (string) Product::factory()->create()->id,
            'unit_id' => (string) Unit::factory()->create()->id,
            'amount' => 1,
            'price' => 10,
        ])->assertStatus(403);

        $this->actingAs($user)
            ->deleteJson("/api/v1/official-prices/{$official->id}")
            ->assertStatus(403);
    }

    #[Test]
    public function official_prices_can_be_searched_by_product_name(): void
    {
        $rice = Product::factory()->create(['name' => 'Rice']);
        $sugar = Product::factory()->create(['name' => 'Sugar']);

        OfficialPrice::factory()->create(['product_id' => $rice->id]);
        OfficialPrice::factory()->create(['product_id' => $sugar->id]);

        $this->getJson('/api/v1/official-prices?search=Rice')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.product_name', 'Rice');
    }
}
