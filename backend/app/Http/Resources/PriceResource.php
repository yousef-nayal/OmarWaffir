<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A submitted market price. There is deliberately no `status` field: the
 * database has no approval lifecycle for prices.
 *
 * @mixin \App\Models\Price
 */
class PriceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $thumbsUp = (int) ($this->thumbs_up ?? $this->ratings->where('value', true)->count());
        $thumbsDown = (int) ($this->thumbs_down ?? $this->ratings->where('value', false)->count());

        return [
            'id' => (string) $this->id,
            'product_id' => (string) $this->product_id,
            'product_name' => $this->product?->name ?? '',
            'store_id' => (string) $this->store_id,
            'store_name' => $this->store?->name ?? '',
            'store_area' => $this->store?->location?->district ?? '',
            'location_id' => $this->store?->location_id !== null ? (string) $this->store->location_id : null,
            'sector_id' => $this->store?->location?->sector_id !== null ? (string) $this->store->location->sector_id : null,
            'sector' => $this->store?->location?->sector?->name ?? '',
            'price' => (float) $this->price,
            'unit' => $this->unit?->name ?? '',
            'unit_id' => (string) $this->unit_id,
            'amount' => (float) $this->amount,
            'brand' => $this->brand?->name ?? '',
            'brand_id' => $this->brand_id !== null ? (string) $this->brand_id : null,
            'user_id' => (string) $this->user_id,
            'submitted_by' => $this->user?->name ?? '',
            'submitted_at' => $this->created_at?->utc()->toIso8601ZuluString(),
            'thumbs_up' => $thumbsUp,
            'thumbs_down' => $thumbsDown,
            'total_ratings' => $thumbsUp + $thumbsDown,
            'my_vote' => $this->when(
                $this->relationLoaded('myRating'),
                fn () => $this->myRating->first()?->value,
            ),
        ];
    }
}
