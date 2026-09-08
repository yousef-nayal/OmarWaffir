<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\User */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $location = $this->whenLoaded('location', fn () => $this->location, $this->location);

        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'phone_number' => $this->phone_number,
            'email' => $this->email,
            // Numeric role: 0 = user, 1 = admin, 2 = super_admin.
            'role' => (int) $this->role,
            'location_id' => $this->location_id !== null ? (string) $this->location_id : null,
            'location' => $location !== null
                ? trim(($location->sector?->name ?? '').' - '.$location->district, ' -')
                : '',
            'district' => $location?->district,
            'sector_id' => $location?->sector_id !== null ? (string) $location->sector_id : null,
            'sector' => $location?->sector?->name,
            'is_active' => (bool) $this->is_active,
            'phone_verified_at' => $this->phone_verified_at?->utc()->toIso8601ZuluString(),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
            'prices_count' => (int) ($this->prices_count ?? 0),
            'ratings_count' => (int) ($this->ratings_count ?? 0),
            'reports_count' => (int) ($this->reports_count ?? 0),
        ];
    }
}
