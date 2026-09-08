<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The aggregate fields below are NOT columns on `products`; they are computed
 * by PriceAggregationService and attached to the model as `aggregates`.
 *
 * @mixin \App\Models\Product
 */
class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        /** @var array<string, mixed> $agg */
        $agg = $this->aggregates ?? [];

        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'category' => $this->category,
            'official_price' => (float) ($agg['official_price'] ?? 0),
            'real_price' => (float) ($agg['real_price'] ?? 0),
            'avg_price' => (float) ($agg['avg_price'] ?? 0),
            'unit' => (string) ($agg['unit'] ?? ''),
            'unit_id' => $agg['unit_id'] ?? null,
            'amount' => (float) ($agg['amount'] ?? 1),
            'prices_count' => (int) ($agg['prices_count'] ?? 0),
            'change_percent' => (float) ($agg['change_percent'] ?? 0),
            'is_price_up' => (bool) ($agg['is_price_up'] ?? true),
            'official_price_id' => $agg['official_price_id'] ?? null,
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
