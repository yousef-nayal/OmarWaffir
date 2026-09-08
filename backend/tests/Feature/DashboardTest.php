<?php

namespace Tests\Feature;

use App\Models\ActivityLog;
use App\Models\Price;
use App\Models\Product;
use App\Models\Report;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DashboardTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function the_counts_are_real_database_aggregates(): void
    {
        $admin = User::factory()->admin()->create();
        User::factory()->count(4)->create();
        Product::factory()->count(3)->create();
        Store::factory()->count(2)->create();
        Price::factory()->count(5)->create();
        Report::factory()->count(2)->create();

        $data = $this->actingAs($admin)
            ->getJson('/api/v1/admin/dashboard-stats')
            ->assertOk()
            ->json('data');

        $this->assertSame(User::count(), $data['totalUsers']);
        $this->assertSame(Product::count(), $data['totalProducts']);
        $this->assertSame(Store::count(), $data['totalStores']);
        $this->assertSame(Price::count(), $data['totalPrices']);
        $this->assertSame(Report::count(), $data['totalReports']);
    }

    #[Test]
    public function growth_compares_the_current_window_with_the_previous_one(): void
    {
        $admin = User::factory()->admin()->create();
        $days = (int) config('waffir.dashboard.growth_period_days');

        // Two products in the previous window, four in the current one.
        Product::factory()->count(2)->create([
            'created_at' => Carbon::now()->subDays($days + 5),
        ]);
        Product::factory()->count(4)->create([
            'created_at' => Carbon::now()->subDay(),
        ]);

        $data = $this->actingAs($admin)
            ->getJson('/api/v1/admin/dashboard-stats')
            ->json('data');

        $this->assertEquals(100.0, $data['productsGrowth']);
    }

    #[Test]
    public function growth_handles_an_empty_previous_window_without_dividing_by_zero(): void
    {
        $admin = User::factory()->admin()->create();

        Store::factory()->count(3)->create(['created_at' => Carbon::now()->subDay()]);

        $data = $this->actingAs($admin)
            ->getJson('/api/v1/admin/dashboard-stats')
            ->json('data');

        $this->assertEquals(100.0, $data['storesGrowth']);
    }

    #[Test]
    public function recent_activity_comes_from_real_logged_events(): void
    {
        $admin = User::factory()->admin()->create();

        ActivityLog::create([
            'type' => ActivityLog::TYPE_PRICE,
            'text' => 'a price was added',
            'created_at' => Carbon::now()->subMinutes(5),
            'updated_at' => Carbon::now()->subMinutes(5),
        ]);

        $this->actingAs($admin)->getJson('/api/v1/admin/recent-activity')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.type', 'price')
            ->assertJsonPath('data.0.text', 'a price was added')
            ->assertJsonPath('data.0.color', 'green')
            ->assertJsonStructure(['data' => [['type', 'text', 'time', 'color', 'created_at']]]);
    }

    #[Test]
    public function submitting_a_price_writes_an_activity_entry(): void
    {
        $user = User::factory()->create();
        $admin = User::factory()->admin()->create();

        $this->actingAs($user)->postJson('/api/v1/prices', [
            'product_id' => (string) Product::factory()->create()->id,
            'store_id' => (string) Store::factory()->create()->id,
            'unit_id' => (string) \App\Models\Unit::factory()->create()->id,
            'amount' => 1,
            'price' => 120,
        ])->assertCreated();

        $this->actingAs($admin)->getJson('/api/v1/admin/recent-activity')
            ->assertOk()
            ->assertJsonPath('data.0.type', 'price');
    }

    #[Test]
    public function the_dashboard_is_admin_only(): void
    {
        $user = User::factory()->create();

        $this->getJson('/api/v1/admin/dashboard-stats')->assertStatus(401);
        $this->actingAs($user)->getJson('/api/v1/admin/dashboard-stats')->assertStatus(403);
    }
}
