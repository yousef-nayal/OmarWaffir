<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Report */
class ReportResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $price = $this->price;

        return [
            'id' => (string) $this->id,
            'price_id' => (string) $this->price_id,
            'type' => $this->type,
            'description' => $this->description,
            'user_id' => (string) $this->user_id,
            'user_name' => $this->user?->name ?? '',
            'product_id' => $price?->product_id !== null ? (string) $price->product_id : null,
            'product_name' => $price?->product?->name ?? '',
            'store_id' => $price?->store_id !== null ? (string) $price->store_id : null,
            'store_name' => $price?->store?->name ?? '',
            'store_area' => $price?->store?->location?->district ?? '',
            'location_id' => $price?->store?->location_id !== null ? (string) $price->store->location_id : null,
            'sector_id' => $price?->store?->location?->sector_id !== null ? (string) $price->store->location->sector_id : null,
            'price' => $price !== null ? (float) $price->price : null,
            'unit' => $price?->unit?->name,
            'amount' => $price !== null ? (float) $price->amount : null,
            'reported_at' => $this->created_at?->utc()->toIso8601ZuluString(),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
