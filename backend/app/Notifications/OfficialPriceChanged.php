<?php

namespace App\Notifications;

use App\Models\OfficialPrice;
use App\Support\Msg;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * In-app (database) notification raised when an official price is published or
 * changed. No push provider is involved - the app reads GET /notifications.
 */
class OfficialPriceChanged extends Notification
{
    use Queueable;

    public function __construct(
        private readonly OfficialPrice $officialPrice,
        private readonly ?float $previousPrice,
    ) {
    }

    /** @return list<string> */
    public function via(object $notifiable): array
    {
        return ['database'];
    }

    /** @return array<string, mixed> */
    public function toDatabase(object $notifiable): array
    {
        $product = $this->officialPrice->product?->name ?? '';
        $new = $this->formatMoney((float) $this->officialPrice->price);

        $body = $this->previousPrice === null
            ? Msg::notificationOfficialPriceAdded($product, $new)
            : Msg::notificationOfficialPriceChanged($product, $this->formatMoney($this->previousPrice), $new);

        return [
            'type' => 'official_price',
            'title' => $product,
            'body' => $body,
            'product_id' => $this->officialPrice->product_id,
            'official_price_id' => $this->officialPrice->id,
            'price' => (float) $this->officialPrice->price,
            'previous_price' => $this->previousPrice,
        ];
    }

    private function formatMoney(float $value): string
    {
        return rtrim(rtrim(number_format($value, 2, '.', ''), '0'), '.');
    }
}
