<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductQuality extends Model
{
    const STATUS_ACTIVE   = 'active';
    const STATUS_ARCHIVED = 'archived';

    protected $fillable = ['quality_name', 'density', 'status'];

    protected function casts(): array
    {
        return [
            'density' => 'integer',
        ];
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }
}
