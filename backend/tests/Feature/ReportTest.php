<?php

namespace Tests\Feature;

use App\Models\Location;
use App\Models\Price;
use App\Models\Product;
use App\Models\Report;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function every_allowed_type_is_accepted(): void
    {
        $user = User::factory()->create();

        foreach (Report::types() as $type) {
            $price = Price::factory()->create();

            $this->actingAs($user)->postJson('/api/v1/reports', [
                'price_id' => (string) $price->id,
                'type' => $type,
                'description' => Report::requiresDescription($type) ? 'Details here' : null,
            ])->assertCreated()->assertJsonPath('data.type', $type);
        }

        $this->assertSame(3, Report::count());
    }

    #[Test]
    public function an_unknown_type_is_rejected(): void
    {
        $user = User::factory()->create();
        $price = Price::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/reports', [
            'price_id' => (string) $price->id,
            'type' => 'wrong_price',
        ])->assertStatus(422)->assertJsonStructure(['errors' => ['type']]);
    }

    #[Test]
    public function the_wrong_information_type_requires_a_description(): void
    {
        $user = User::factory()->create();
        $price = Price::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/reports', [
            'price_id' => (string) $price->id,
            'type' => Report::TYPE_WRONG_INFO,
        ])->assertStatus(422)->assertJsonStructure(['errors' => ['description']]);
    }

    #[Test]
    public function a_description_sent_with_another_type_is_dropped(): void
    {
        // The database CHECK forbids it, so the API must not try to store it.
        $user = User::factory()->create();
        $price = Price::factory()->create();

        $this->actingAs($user)->postJson('/api/v1/reports', [
            'price_id' => (string) $price->id,
            'type' => Report::TYPE_OVERPRICED,
            'description' => 'this should be ignored',
        ])->assertCreated()->assertJsonPath('data.description', null);

        $this->assertDatabaseHas('reports', [
            'type' => Report::TYPE_OVERPRICED,
            'description' => null,
        ]);
    }

    #[Test]
    public function an_anonymous_visitor_cannot_report(): void
    {
        $price = Price::factory()->create();

        $this->postJson('/api/v1/reports', [
            'price_id' => (string) $price->id,
            'type' => Report::TYPE_OVERPRICED,
        ])->assertStatus(401);
    }

    #[Test]
    public function the_report_payload_has_what_the_detail_sheet_needs(): void
    {
        $admin = User::factory()->admin()->create();
        $product = Product::factory()->create(['name' => 'Sugar']);
        $location = Location::factory()->create();
        $store = Store::factory()->create(['location_id' => $location->id]);
        $price = Price::factory()->create([
            'product_id' => $product->id,
            'store_id' => $store->id,
        ]);
        Report::factory()->create(['price_id' => $price->id]);

        $this->actingAs($admin)->getJson('/api/v1/reports')
            ->assertOk()
            ->assertJsonPath('data.0.product_name', 'Sugar')
            ->assertJsonPath('data.0.store_name', $store->name)
            ->assertJsonPath('data.0.store_area', $location->district)
            ->assertJsonStructure([
                'data' => [[
                    'id', 'price_id', 'type', 'description', 'user_id', 'user_name',
                    'product_name', 'store_name', 'store_area', 'location_id',
                    'sector_id', 'price', 'unit', 'amount', 'reported_at',
                ]],
            ]);
    }

    #[Test]
    public function an_admin_can_filter_and_delete_reports(): void
    {
        $admin = User::factory()->admin()->create();

        $overpriced = Report::factory()->create(['type' => Report::TYPE_OVERPRICED]);
        Report::factory()->create(['type' => Report::TYPE_WRONG_PRICE]);

        $this->actingAs($admin)
            ->getJson('/api/v1/reports?type='.urlencode(Report::TYPE_OVERPRICED))
            ->assertOk()
            ->assertJsonPath('pagination.total', 1);

        $this->actingAs($admin)
            ->deleteJson("/api/v1/reports/{$overpriced->id}")
            ->assertOk();

        $this->assertDatabaseMissing('reports', ['id' => $overpriced->id]);
    }

    #[Test]
    public function a_normal_user_cannot_list_or_delete_reports(): void
    {
        $user = User::factory()->create();
        $report = Report::factory()->create();

        $this->actingAs($user)->getJson('/api/v1/reports')->assertStatus(403);
        $this->actingAs($user)->deleteJson("/api/v1/reports/{$report->id}")->assertStatus(403);
    }
}
