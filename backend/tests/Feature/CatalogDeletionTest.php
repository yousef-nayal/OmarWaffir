<?php

namespace Tests\Feature;

use App\Models\Brand;
use App\Models\Location;
use App\Models\OfficialPrice;
use App\Models\Price;
use App\Models\Sector;
use App\Models\Store;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Deleting a catalogue row takes the prices recorded against it with it, and
 * the admin is told how many before confirming. Deletion used to be refused
 * with 409 while anything referenced the row, which left no way to remove a
 * wrong unit or brand at all.
 */
class CatalogDeletionTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->admin()->create();
    }

    #[Test]
    public function deleting_a_unit_deletes_its_prices_and_official_prices(): void
    {
        $unit = Unit::factory()->create();
        $price = Price::factory()->create(['unit_id' => $unit->id]);
        $official = OfficialPrice::factory()->create(['unit_id' => $unit->id]);
        $survivor = Price::factory()->create();

        $this->actingAs($this->admin())
            ->getJson("/api/v1/admin/deletion-impact/unit/{$unit->id}")
            ->assertOk()
            ->assertJsonPath('data.prices', 1)
            ->assertJsonPath('data.official_prices', 1);

        $this->actingAs($this->admin())
            ->deleteJson("/api/v1/units/{$unit->id}")
            ->assertOk();

        $this->assertDatabaseMissing('units', ['id' => $unit->id]);
        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseMissing('official_prices', ['id' => $official->id]);
        $this->assertDatabaseHas('prices', ['id' => $survivor->id]);
    }

    #[Test]
    public function deleting_a_brand_deletes_the_prices_recorded_under_it(): void
    {
        $brand = Brand::factory()->create();
        $price = Price::factory()->create(['brand_id' => $brand->id]);
        $unbranded = Price::factory()->create(['brand_id' => null]);

        $this->actingAs($this->admin())
            ->getJson("/api/v1/admin/deletion-impact/brand/{$brand->id}")
            ->assertOk()
            ->assertJsonPath('data.prices', 1);

        $this->actingAs($this->admin())
            ->deleteJson("/api/v1/brands/{$brand->id}")
            ->assertOk();

        $this->assertDatabaseMissing('brands', ['id' => $brand->id]);
        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseHas('prices', ['id' => $unbranded->id]);
    }

    #[Test]
    public function deleting_a_user_deletes_the_prices_they_submitted(): void
    {
        $author = User::factory()->create();
        $price = Price::factory()->create(['user_id' => $author->id]);
        $survivor = Price::factory()->create();

        $this->actingAs($this->admin())
            ->getJson("/api/v1/admin/deletion-impact/user/{$author->id}")
            ->assertOk()
            ->assertJsonPath('data.prices', 1);

        $this->actingAs($this->admin())
            ->deleteJson("/api/v1/admin/users/{$author->id}")
            ->assertOk();

        $this->assertSoftDeleted('users', ['id' => $author->id]);
        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseHas('prices', ['id' => $survivor->id]);
    }

    #[Test]
    public function deleting_an_area_takes_its_shops_and_their_prices(): void
    {
        $location = Location::factory()->create();
        $store = Store::factory()->create(['location_id' => $location->id]);
        $price = Price::factory()->create(['store_id' => $store->id]);

        // A soft-deleted shop still holds the foreign key, so it has to go too.
        $goneStore = Store::factory()->create(['location_id' => $location->id]);
        $goneStore->delete();

        $resident = User::factory()->create(['location_id' => $location->id]);
        $elsewhere = Price::factory()->create();

        $this->actingAs($this->admin())
            ->getJson("/api/v1/admin/deletion-impact/location/{$location->id}")
            ->assertOk()
            ->assertJsonPath('data.prices', 1)
            ->assertJsonPath('data.stores', 2)
            ->assertJsonPath('data.users', 1);

        $this->actingAs($this->admin())
            ->deleteJson("/api/v1/locations/{$location->id}")
            ->assertOk();

        $this->assertDatabaseMissing('locations', ['id' => $location->id]);
        $this->assertDatabaseMissing('stores', ['id' => $store->id]);
        $this->assertDatabaseMissing('stores', ['id' => $goneStore->id]);
        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseHas('prices', ['id' => $elsewhere->id]);

        // The account survives; only the link to the deleted area is cleared.
        $this->assertDatabaseHas('users', ['id' => $resident->id, 'location_id' => null]);
    }

    #[Test]
    public function deleting_a_block_takes_its_areas_shops_and_prices(): void
    {
        $sector = Sector::factory()->create();
        $first = Location::factory()->create(['sector_id' => $sector->id]);
        $second = Location::factory()->create(['sector_id' => $sector->id]);
        $store = Store::factory()->create(['location_id' => $first->id]);
        $price = Price::factory()->create(['store_id' => $store->id]);

        $otherSector = Sector::factory()->create();
        $otherLocation = Location::factory()->create(['sector_id' => $otherSector->id]);

        $this->actingAs($this->admin())
            ->getJson("/api/v1/admin/deletion-impact/sector/{$sector->id}")
            ->assertOk()
            ->assertJsonPath('data.locations', 2)
            ->assertJsonPath('data.stores', 1)
            ->assertJsonPath('data.prices', 1);

        $this->actingAs($this->admin())
            ->deleteJson("/api/v1/sectors/{$sector->id}")
            ->assertOk();

        $this->assertSoftDeleted('sectors', ['id' => $sector->id]);
        $this->assertDatabaseMissing('locations', ['id' => $first->id]);
        $this->assertDatabaseMissing('locations', ['id' => $second->id]);
        $this->assertDatabaseMissing('prices', ['id' => $price->id]);
        $this->assertDatabaseHas('locations', ['id' => $otherLocation->id]);
    }

    #[Test]
    public function an_untouched_row_reports_an_empty_impact(): void
    {
        $unit = Unit::factory()->create();

        $this->actingAs($this->admin())
            ->getJson("/api/v1/admin/deletion-impact/unit/{$unit->id}")
            ->assertOk()
            ->assertJsonPath('data.prices', 0)
            ->assertJsonPath('data.official_prices', 0);
    }

    #[Test]
    public function the_impact_of_a_missing_row_is_a_404(): void
    {
        $this->actingAs($this->admin())
            ->getJson('/api/v1/admin/deletion-impact/unit/999999')
            ->assertStatus(404);
    }

    #[Test]
    public function a_normal_user_cannot_read_the_deletion_impact(): void
    {
        $unit = Unit::factory()->create();

        $this->actingAs(User::factory()->create())
            ->getJson("/api/v1/admin/deletion-impact/unit/{$unit->id}")
            ->assertStatus(403);
    }
}
