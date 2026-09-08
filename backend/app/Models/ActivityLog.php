<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ActivityLog extends Model
{
    use HasFactory;

    public const TYPE_PRICE = 'price';
    public const TYPE_REPORT = 'report';
    public const TYPE_USER = 'user';
    public const TYPE_STORE = 'store';
    public const TYPE_OFFICIAL = 'official';

    protected $fillable = [
        'type',
        'text',
        'user_id',
        'subject_type',
        'subject_id',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class)->withTrashed();
    }

    /** UI colour hint consumed by the admin dashboard "recent activity" list. */
    public function color(): string
    {
        return match ($this->type) {
            self::TYPE_PRICE => 'green',
            self::TYPE_REPORT => 'red',
            self::TYPE_USER => 'blue',
            self::TYPE_STORE => 'purple',
            self::TYPE_OFFICIAL => 'orange',
            default => 'grey',
        };
    }
}
