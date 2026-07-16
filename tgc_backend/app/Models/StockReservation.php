<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class StockReservation extends Model
{
    use HasFactory;

    const STATUS_ACTIVE    = 'active';
    const STATUS_FULFILLED = 'fulfilled';
    const STATUS_RELEASED  = 'released';
    const STATUS_EXPIRED   = 'expired';

    protected $fillable = [
        'product_variant_id',
        'order_item_id',
        'quantity',
        'status',
        'reserved_by',
        'reserved_at',
        'released_at',
        'release_reason',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'quantity'    => 'integer',
            'reserved_at' => 'datetime',
            'released_at' => 'datetime',
            'expires_at'  => 'datetime',
        ];
    }

    public function variant(): BelongsTo
    {
        return $this->belongsTo(ProductVariant::class, 'product_variant_id');
    }

    public function orderItem(): BelongsTo
    {
        return $this->belongsTo(OrderItem::class);
    }

    public function reservedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reserved_by');
    }
}
