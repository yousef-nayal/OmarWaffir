<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Report extends Model
{
    use HasFactory;

    /** "سعر مبالغ فيه" */
    public const TYPE_OVERPRICED = 'سعر مبالغ فيه';

    /** "سعر غير صحيح" */
    public const TYPE_WRONG_PRICE = 'سعر غير صحيح';

    /** "معلومات غير صحيحة" - the only type that carries a description. */
    public const TYPE_WRONG_INFO = 'معلومات غير صحيحة';

    protected $fillable = ['user_id', 'price_id', 'type', 'description'];

    /** @return list<string> */
    public static function types(): array
    {
        return [self::TYPE_OVERPRICED, self::TYPE_WRONG_PRICE, self::TYPE_WRONG_INFO];
    }

    public static function requiresDescription(string $type): bool
    {
        return $type === self::TYPE_WRONG_INFO;
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class)->withTrashed();
    }

    public function price(): BelongsTo
    {
        return $this->belongsTo(Price::class);
    }
}
