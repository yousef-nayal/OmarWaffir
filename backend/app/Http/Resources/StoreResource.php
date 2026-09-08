<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Store */
class StoreResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'location_id' => (string) $this->location_id,
            'name' => $this->name,
            'address' => $this->address,
            // Canonical district plus the `area` alias the Flutter UI displays.
            'district' => $this->location?->district ?? '',
            'area' => $this->location?->district ?? '',
            'sector_id' => $this->location?->sector_id !== null ? (string) $this->location->sector_id : null,
            'sector' => $this->location?->sector?->name ?? '',
            'is_verified' => (bool) $this->is_verified,
            'prices_count' => (int) ($this->prices_count ?? 0),
            'submitted_by_user_id' => $this->submitted_by_user_id !== null ? (string) $this->submitted_by_user_id : null,
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
