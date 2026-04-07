<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SaleItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'sale_id',
        'product_id',
        'product_size_id',
        'quantity',
        'price',
        'subtotal',
    ];

    protected function casts(): array
    {
        return [
            'quantity'        => 'integer',
            'price'           => 'decimal:2',
            'subtotal'        => 'decimal:2',
            'product_size_id' => 'integer',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function productSize(): BelongsTo
    {
        return $this->belongsTo(ProductSize::class);
    }
}
