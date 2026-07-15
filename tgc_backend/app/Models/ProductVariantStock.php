<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductVariantStock extends Model
{
    protected $table      = 'product_variant_stock';
    protected $primaryKey = 'product_variant_id';
    public $incrementing  = false;

    protected $fillable = ['product_variant_id', 'quantity'];

    protected function casts(): array
    {
        return ['quantity' => 'integer'];
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }
}
