<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Unit */
class UnitResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'usage_count' => (int) ($this->prices_count ?? 0) + (int) ($this->official_prices_count ?? 0),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
