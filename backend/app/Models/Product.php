<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Product extends Model
{
    use HasFactory;
    use SoftDeletes;

    protected $fillable = ['name', 'category'];

    public function prices(): HasMany
    {
        return $this->hasMany(Price::class);
    }

    public function officialPrices(): HasMany
    {
        return $this->hasMany(OfficialPrice::class);
    }
}
