<?php

namespace Tests\Feature;

use App\Models\Location;
use App\Models\OfficialPrice;
use App\Models\Price;
use App\Models\Product;
use App\Models\Store;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class ProductTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function it_lists_products_with_pagination(): void
    {
        Product::factory()->count(25)->create();

        $this->getJson('/api/v1/products?per_page=10')
            ->assertOk()
            ->assertJsonCount(10, 'data')
            ->assertJsonPath('pagination.current_page', 1)
            ->assertJsonPath('pagination.per_page', 10)
            ->assertJsonPath('pagination.total', 25)
            ->assertJsonPath('pagination.last_page', 3);
    }

    #[Test]
    public function it_searches_by_name(): void
    {
        Product::factory()->create(['name' => 'Olive Oil']);
        Product::factory()->create(['name' => 'Sugar']);

        $this->getJson('/api/v1/products?search=Olive')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Olive Oil');
    }

    #[Test]
    public function it_filters_by_category(): void
    {
        Product::factory()->create(['category' => 'oils']);
        Product::factory()->count(2)->create(['category' => 'grains']);

        $this->getJson('/api/v1/products?category=grains')
            ->assertOk()
            ->assertJsonCount(2, 'data');
    }

    #[Test]
    public function the_aggregate_fields_are_computed_and_not_stored(): void
    {
        // products has no official_price / real_price / avg_price column.
        $this->assertFalse(
            \Illuminate\Support\Facades\Schema::hasColumn('products', 'official_price'),
        );
        $this->assertFalse(
            \Illuminate\Support\Facades\Schema::hasColumn('products', 'real_price'),
        );
        $this->assertFalse(
            \Illuminate\Support\Facades\Schema::hasColumn('products', 'prices_count'),
        );
    }

    #[Test]
    public function market_values_are_specific_to_the_requested_location(): void
    {
        $unit = Unit::factory()->create(['name' => 'kg']);
        $product = Product::factory()->create();

        OfficialPrice::factory()->create([
            'product_id' => $product->id,
            'unit_id' => $unit->id,
            'amount' => 1,
            'price' => 100,
        ]);

        $cheapLocation = Location::factory()->create();
        $pricyLocation = Location::factory()->create();

        $cheapStore = Store::factory()->create(['location_id' => $cheapLocation->id]);
        $pricyStore = Store::factory()->create(['location_id' => $pricyLocation->id]);

        foreach ([90, 92, 94] as $value) {
            Price::factory()->create([
                'product_id' => $product->id,
                'store_id' => $cheapStore->id,
                'unit_id' => $unit->id,
                'amount' => 1,
                'price' => $value,
            ]);
        }

        foreach ([180, 182, 184] as $value) {
            Price::factory()->create([
                'product_id' => $product->id,
                'store_id' => $pricyStore->id,
                'unit_id' => $unit->id,
                'amount' => 1,
                'price' => $value,
            ]);
        }

        $cheap = $this->getJson("/api/v1/products?location_id={$cheapLocation->id}")
            ->assertOk()
            ->json('data.0');

        $pricy = $this->getJson("/api/v1/products?location_id={$pricyLocation->id}")
            ->assertOk()
            ->json('data.0');

        $this->assertEquals(92.0, $cheap['real_price']);
        $this->assertSame(3, $cheap['prices_count']);
        $this->assertFalse($cheap['is_price_up']);
        $this->assertEquals(-8.0, $cheap['change_percent']);

        $this->assertEquals(182.0, $pricy['real_price']);
        $this->assertTrue($pricy['is_price_up']);
        $this->assertEquals(82.0, $pricy['change_percent']);

        // Without a location filter, every submission counts.
        $all = $this->getJson('/api/v1/products')->json('data.0');
        $this->assertSame(6, $all['prices_count']);
    }

    #[Test]
    public function amounts_are_normalised_before_aggregation(): void
    {
        $unit = Unit::factory()->create();
        $product = Product::factory()->create();
        $store = Store::factory()->create();

        OfficialPrice::factory()->create([
            'product_id' => $product->id,
            'unit_id' => $unit->id,
            'amount' => 1,
            'price' => 100,
        ]);

        // 1 unit at 100 and 2 units at 200 are the same unit price.
        Price::factory()->create([
            'product_id' => $product->id, 'store_id' => $store->id,
            'unit_id' => $unit->id, 'amount' => 1, 'price' => 100,
        ]);
        Price::factory()->create([
            'product_id' => $product->id, 'store_id' => $store->id,
            'unit_id' => $unit->id, 'amount' => 2, 'price' => 200,
        ]);

        $data = $this->getJson("/api/v1/products/{$product->id}")->assertOk()->json('data');

        $this->assertEquals(100.0, $data['real_price']);
        $this->assertEquals(100.0, $data['avg_price']);
        $this->assertEquals(0.0, $data['change_percent']);
    }

    #[Test]
    public function stale_submissions_are_ignored(): void
    {
        $unit = Unit::factory()->create();
        $product = Product::factory()->create();
        $store = Store::factory()->create();

        OfficialPrice::factory()->create([
            'product_id' => $product->id, 'unit_id' => $unit->id,
            'amount' => 1, 'price' => 100,
        ]);

        Price::factory()->create([
            'product_id' => $product->id, 'store_id' => $store->id,
            'unit_id' => $unit->id, 'amount' => 1, 'price' => 500,
            'created_at' => Carbon::now()->subDays(120),
        ]);

        $data = $this->getJson("/api/v1/products/{$product->id}")->json('data');

        $this->assertSame(0, $data['prices_count']);
        $this->assertEquals(0.0, $data['real_price']);
        $this->assertEquals(100.0, $data['official_price']);
    }

    #[Test]
    public function a_product_without_market_data_reports_zeroes(): void
    {
        $product = Product::factory()->create();

        $data = $this->getJson("/api/v1/products/{$product->id}")->assertOk()->json('data');

        $this->assertEquals(0.0, $data['real_price']);
        $this->assertEquals(0.0, $data['avg_price']);
        $this->assertEquals(0.0, $data['official_price']);
        $this->assertSame(0, $data['prices_count']);
    }

    #[Test]
    public function the_official_price_comes_from_the_newest_official_row(): void
    {
        $unit = Unit::factory()->create();
        $product = Product::factory()->create();

        OfficialPrice::factory()->create([
            'product_id' => $product->id, 'unit_id' => $unit->id,
            'amount' => 1, 'price' => 100,
            'created_at' => Carbon::now()->subDays(30),
        ]);
        OfficialPrice::factory()->create([
            'product_id' => $product->id, 'unit_id' => $unit->id,
            'amount' => 1, 'price' => 150,
            'created_at' => Carbon::now()->subDay(),
        ]);

        $data = $this->getJson("/api/v1/products/{$product->id}")->json('data');

        $this->assertEquals(150.0, $data['official_price']);
    }

    #[Test]
    public function product_prices_can_be_listed_and_filtered_by_location(): void
    {
        $product = Product::factory()->create();
        $location = Location::factory()->create();
        $store = Store::factory()->create(['location_id' => $location->id]);
        $elsewhere = Store::factory()->create();

        Price::factory()->create(['product_id' => $product->id, 'store_id' => $store->id]);
        Price::factory()->create(['product_id' => $product->id, 'store_id' => $elsewhere->id]);

        $this->getJson("/api/v1/products/{$product->id}/prices")
            ->assertOk()
            ->assertJsonCount(2, 'data');

        $this->getJson("/api/v1/products/{$product->id}/prices?location_id={$location->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.store_id', (string) $store->id);
    }

    #[Test]
    public function deleting_a_product_keeps_its_historical_prices(): void
    {
        $admin = User::factory()->admin()->create();
        $product = Product::factory()->create();
        $price = Price::factory()->create(['product_id' => $product->id]);

        $this->actingAs($admin)
            ->deleteJson("/api/v1/products/{$product->id}")
            ->assertOk();

        $this->assertSoftDeleted('products', ['id' => $product->id]);
        $this->assertDatabaseHas('prices', ['id' => $price->id]);
    }
}
