<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductEdge extends Model
{
    protected $fillable = ['code', 'title'];

    public function productVariants(): HasMany
    {
        return $this->hasMany(ProductVariant::class);
    }
}
