<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \Illuminate\Notifications\DatabaseNotification */
class NotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $data = $this->data ?? [];

        return [
            'id' => (string) $this->id,
            'type' => $data['type'] ?? 'general',
            'title' => $data['title'] ?? '',
            'body' => $data['body'] ?? '',
            'product_id' => isset($data['product_id']) ? (string) $data['product_id'] : null,
            'is_read' => $this->read_at !== null,
            'read_at' => $this->read_at?->utc()->toIso8601ZuluString(),
            'created_at' => $this->created_at?->utc()->toIso8601ZuluString(),
        ];
    }
}
