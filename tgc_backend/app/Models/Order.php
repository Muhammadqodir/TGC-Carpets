<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class Order extends Model
{
    use HasFactory;

    const STATUS_PENDING       = 'pending';
    const STATUS_PLANNED        = 'planned';
    const STATUS_ON_PRODUCTION  = 'on_production';
    const STATUS_DONE           = 'done';
    const STATUS_SHIPPED        = 'shipped';
    const STATUS_CANCELED       = 'canceled';

    const STATUSES = [
        self::STATUS_PENDING,
        self::STATUS_PLANNED,
        self::STATUS_ON_PRODUCTION,
        self::STATUS_DONE,
        self::STATUS_SHIPPED,
        self::STATUS_CANCELED,
    ];

    protected $fillable = [
        'uuid',
        'external_uuid',
        'user_id',
        'client_id',
        'status',
        'order_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'order_date' => 'date',
        ];
    }

    protected static function boot(): void
    {
        parent::boot();

        static::creating(function (Order $order): void {
            if (empty($order->uuid)) {
                $order->uuid = (string) Str::uuid();
            }
        });
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

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }
}
