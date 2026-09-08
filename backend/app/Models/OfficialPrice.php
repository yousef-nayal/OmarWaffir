<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Official prices are immutable historical events: an administrative "update"
 * inserts a new row rather than mutating an existing one. The newest row for a
 * (product_id, unit_id, amount) tuple is the current official price.
 */
class OfficialPrice extends Model
{
    use HasFactory;

    public const UPDATED_AT = null;

    protected $fillable = [
        'product_id',
        'unit_id',
        'amount',
        'price',
        'created_by',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:3',
            'price' => 'decimal:2',
            'created_at' => 'datetime',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class)->withTrashed();
    }

    public function unit(): BelongsTo
    {
        return $this->belongsTo(Unit::class);
    }

    public function createdBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by')->withTrashed();
    }

    /**
     * Restricts the query to the newest row of every
     * (product_id, unit_id, amount) series - i.e. the current official prices.
     */
    public function scopeCurrent(Builder $query): Builder
    {
        return $query->whereIn('id', function ($sub) {
            $sub->selectRaw('MAX(id)')
                ->from('official_prices')
                ->groupBy('product_id', 'unit_id', 'amount');
        });
    }
}
