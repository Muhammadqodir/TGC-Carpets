<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Payment extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'user_id',
        'client_id',
        'order_id',
        'amount',
        'notes',
        'currency',
        'exchange_rate',
    ];

    protected function casts(): array
    {
        return [
            'amount'        => 'decimal:2',
            'exchange_rate' => 'decimal:8',
        ];
    }

    /** amount converted to base currency using this row's own frozen rate. */
    public function baseAmount(): string
    {
        $rate = (string) $this->getRawOriginal('exchange_rate');

        return bcadd(bcmul((string) $this->getRawOriginal('amount'), $rate, 8), '0.005', 2);
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }
}
