<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\OfficialPrice */
class OfficialPriceHistoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'price' => (float) $this->price,
            'amount' => (float) $this->amount,
            'unit' => $this->unit?->name ?? '',
            'changed_at' => $this->created_at?->utc()->toIso8601ZuluString(),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
