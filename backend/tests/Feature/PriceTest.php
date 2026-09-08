<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\Location;
use App\Models\Price;
use App\Models\Product;
use App\Models\Rating;
use App\Models\Report;
use App\Models\Store;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class PriceTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function an_authenticated_user_can_submit_a_price(): void
    {
        $user = User::factory()->create();
        $product = Product::factory()->create();
        $store = Store::factory()->create();
        $unit = Unit::factory()->create();
        $brand = Brand::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/prices', [
            'product_id' => (string) $product->id,
            'store_id' => (string) $store->id,
            'unit_id' => (string) $unit->id,
            'brand_id' => (string) $brand->id,
            'amount' => 2,
            'price' => 250,
        ])->assertCreated()
            ->assertJsonPath('data.product_id', (string) $product->id)
            ->assertJsonPath('data.price', 250)
            ->assertJsonPath('data.amount', 2)
            ->assertJsonPath('data.submitted_by', $user->name)
            ->assertJsonMissingPath('data.status');

        $this->assertDatabaseHas('prices', [
            'user_id' => $user->id,
            'product_id' => $product->id,
            'store_id' => $store->id,
        ]);
    }

    #[Test]
    public function the_author_is_taken_from_the_session_not_the_request_body(): void
    {
        $user = User::factory()->create();
        $someoneElse = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/prices', [
            'product_id' => (string) Product::factory()->create()->id,
            'store_id' => (string) Store::factory()->create()->id,
            'unit_id' => (string) Unit::factory()->create()->id,
            'amount' => 1,
            'price' => 100,
            // Spoofing attempt:
            'user_id' => $someoneElse->id,
        ])->assertCreated();

        $this->assertDatabaseHas('prices', ['user_id' => $user->id]);
        $this->assertDatabaseMissing('prices', ['user_id' => $someoneElse->id]);
    }

    #[Test]
    public function invalid_relationships_are_rejected(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/prices', [
            'product_id' => '999999',
            'store_id' => '999999',
            'unit_id' => '999999',
            'amount' => 1,
            'price' => 100,
        ])->assertStatus(422)
            ->assertJsonStructure(['errors' => ['product_id', 'store_id', 'unit_id']]);
    }

    #[Test]
    public function a_non_positive_amount_is_rejected(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/prices', [
            'product_id' => (string) Product::factory()->create()->id,
            'store_id' => (string) Store::factory()->create()->id,
            'unit_id' => (string) Unit::factory()->create()->id,
            'amount' => 0,
            'price' => 100,
        ])->assertStatus(422)->assertJsonStructure(['errors' => ['amount']]);
    }

    #[Test]
    public function an_anonymous_visitor_cannot_submit_a_price(): void
    {
        $this->postJson('/api/v1/prices', [
            'product_id' => (string) Product::factory()->create()->id,
            'store_id' => (string) Store::factory()->create()->id,
            'unit_id' => (string) Unit::factory()->create()->id,
            'amount' => 1,
            'price' => 100,
        ])->assertStatus(401);
    }

    #[Test]
    public function a_price_carries_its_location_through_the_store(): void
    {
        $location = Location::factory()->create();
        $store = Store::factory()->create(['location_id' => $location->id]);
        $price = Price::factory()->create(['store_id' => $store->id]);
        $admin = User::factory()->admin()->create();

        $this->actingAs($admin)->getJson('/api/v1/prices')
            ->assertOk()
            ->assertJsonPath('data.0.location_id', (string) $location->id)
            ->assertJsonPath('data.0.sector_id', (string) $location->sector_id)
            ->assertJsonPath('data.0.store_area', $location->district)
            ->assertJsonPath('data.0.id', (string) $price->id);
    }

    #[Test]
    public function a_user_can_vote_once_and_change_their_vote(): void
    {
        $author = User::factory()->create();
        $voter = User::factory()->create();
        $price = Price::factory()->create(['user_id' => $author->id]);

        $this->actingAs($voter)
            ->postJson("/api/v1/prices/{$price->id}/vote", ['is_up' => true])
            ->assertOk()
            ->assertJsonPath('data.thumbs_up', 1)
            ->assertJsonPath('data.thumbs_down', 0);

        // Voting the same way again is idempotent.
        $this->actingAs($voter)
            ->postJson("/api/v1/prices/{$price->id}/vote", ['is_up' => true])
            ->assertOk()
            ->assertJsonPath('data.thumbs_up', 1)
            ->assertJsonPath('data.total_ratings', 1);

        // Changing the vote updates the existing rating rather than adding one.
        $this->actingAs($voter)
            ->postJson("/api/v1/prices/{$price->id}/vote", ['is_up' => false])
            ->assertOk()
            ->assertJsonPath('data.thumbs_up', 0)
            ->assertJsonPath('data.thumbs_down', 1);

        $this->assertSame(1, Rating::where('price_id', $price->id)->count());
    }

    #[Test]
    public function a_user_cannot_rate_their_own_price(): void
    {
        $author = User::factory()->create();
        $price = Price::factory()->create(['user_id' => $author->id]);

        $this->actingAs($author)
            ->postJson("/api/v1/prices/{$price->id}/vote", ['is_up' => true])
            ->assertStatus(403)
            ->assertJsonPath('success', false);

        $this->assertSame(0, Rating::where('price_id', $price->id)->count());
    }

    #[Test]
    public function an_admin_can_filter_the_review_list(): void
    {
        $admin = User::factory()->admin()->create();

        $product = Product::factory()->create(['name' => 'Rice']);
        $location = Location::factory()->create();
        $store = Store::factory()->create(['location_id' => $location->id]);

        Price::factory()->create(['product_id' => $product->id, 'store_id' => $store->id]);
        Price::factory()->count(2)->create();

        $this->actingAs($admin)->getJson('/api/v1/prices')
            ->assertOk()->assertJsonPath('pagination.total', 3);

        $this->actingAs($admin)->getJson("/api/v1/prices?product_id={$product->id}")
            ->assertOk()->assertJsonPath('pagination.total', 1);

        $this->actingAs($admin)->getJson("/api/v1/prices?location_id={$location->id}")
            ->assertOk()->assertJsonPath('pagination.total', 1);

        $this->actingAs($admin)->getJson('/api/v1/prices?search=Rice')
            ->assertOk()->assertJsonPath('pagination.total', 1);
    }

    #[Test]
    public function an_admin_deleting_a_price_removes_its_ratings_and_reports(): void
    {
        $admin = User::factory()->admin()->create();
        $price = Price::factory()->create();

        Rating::create([
            'user_id' => User::factory()->create()->id,
            'price_id' => $price->id,
            'value' => true,
        ]);
        Report::factory()->create(['price_id' => $price->id]);

        $this->actingAs($admin)->deleteJson("/api/v1/prices/{$price->id}")->assertOk();

        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseMissing('ratings', ['price_id' => $price->id]);
        $this->assertDatabaseMissing('reports', ['price_id' => $price->id]);
    }

    #[Test]
    public function a_normal_user_cannot_delete_a_price(): void
    {
        $user = User::factory()->create();
        $price = Price::factory()->create();

        $this->actingAs($user)->deleteJson("/api/v1/prices/{$price->id}")
            ->assertStatus(403);

        $this->assertDatabaseHas('prices', ['id' => $price->id]);
    }
}
