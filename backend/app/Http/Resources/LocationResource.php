<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Location */
class LocationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'sector_id' => (string) $this->sector_id,
            'sector' => $this->sector?->name ?? '',
            // `district` is canonical; `area` is kept as a UI-compatibility alias.
            'district' => $this->district,
            'area' => $this->district,
            'landmark' => '',
            'stores_count' => (int) ($this->stores_count ?? 0),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
