<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductSize extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = ['length', 'width', 'product_type_id'];

    protected function casts(): array
    {
        return [
            'length' => 'integer',
            'width'  => 'integer',
        ];
    }

    public function productType(): BelongsTo
    {
        return $this->belongsTo(ProductType::class)->withTrashed();
    }

    public function variants(): HasMany
    {
        return $this->hasMany(ProductVariant::class);
    }
}
