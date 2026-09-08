<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Brand */
class BrandResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            // Number of distinct products this brand has been priced against.
            'products_count' => (int) ($this->products_count ?? 0),
            'usage_count' => (int) ($this->prices_count ?? 0),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
