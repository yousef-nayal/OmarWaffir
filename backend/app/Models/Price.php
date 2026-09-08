<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Price extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'store_id',
        'product_id',
        'unit_id',
        'brand_id',
        'amount',
        'price',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:3',
            'price' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class)->withTrashed();
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class)->withTrashed();
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class)->withTrashed();
    }

    public function unit(): BelongsTo
    {
        return $this->belongsTo(Unit::class);
    }

    public function brand(): BelongsTo
    {
        return $this->belongsTo(Brand::class);
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(Rating::class);
    }

    public function reports(): HasMany
    {
        return $this->hasMany(Report::class);
    }

    /** Constrained at query time to the authenticated user's own rating. */
    public function myRating(): HasMany
    {
        return $this->hasMany(Rating::class);
    }

    /** Price normalised to a single unit of measure (price per 1 amount). */
    public function unitPrice(): float
    {
        $amount = (float) $this->amount;

        return $amount > 0 ? (float) $this->price / $amount : 0.0;
    }
}
