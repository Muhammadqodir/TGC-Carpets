<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductType extends Model
{
    use HasFactory;

    const STATUS_ACTIVE   = 'active';
    const STATUS_ARCHIVED = 'archived';

    protected $fillable = ['type', 'status', 'is_printable'];

    protected $casts = [
        'is_printable' => 'boolean',
    ];

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function sizes(): HasMany
    {
        return $this->hasMany(ProductSize::class);
    }
}
