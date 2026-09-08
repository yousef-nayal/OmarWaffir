<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\OfficialPrice */
class OfficialPriceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'product_id' => (string) $this->product_id,
            'product_name' => $this->product?->name ?? '',
            'category' => $this->product?->category ?? '',
            'unit_id' => (string) $this->unit_id,
            'unit' => $this->unit?->name ?? '',
            'amount' => (float) $this->amount,
            'price' => (float) $this->price,
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
            // The Flutter model falls back to created_at, but being explicit
            // keeps "last changed" unambiguous for an immutable event row.
            'updated_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
