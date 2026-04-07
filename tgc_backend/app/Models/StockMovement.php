<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

class StockMovement extends Model
{
    use HasFactory;

    const TYPE_IN         = 'in';
    const TYPE_OUT        = 'out';
    const TYPE_ADJUSTMENT = 'adjustment';
    const TYPE_RETURN     = 'return';

    const TYPES = [
        self::TYPE_IN,
        self::TYPE_OUT,
        self::TYPE_ADJUSTMENT,
        self::TYPE_RETURN,
    ];

    protected $fillable = [
        'uuid',
        'product_id',
        'product_size_id',
        'warehouse_document_id',
        'sale_id',
        'client_id',
        'user_id',
        'movement_type',
        'quantity',
        'movement_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'quantity'        => 'integer',
            'movement_date'   => 'datetime',
            'product_size_id' => 'integer',
        ];
    }

    protected static function boot(): void
    {
        parent::boot();

        static::creating(function (StockMovement $movement): void {
            if (empty($movement->uuid)) {
                $movement->uuid = (string) Str::uuid();
            }
        });
    }

    // ── Direction helpers ─────────────────────────────────────────────────────

    /**
     * Returns true for movement types that add stock.
     */
    public function isIncoming(): bool
    {
        return in_array($this->movement_type, [self::TYPE_IN, self::TYPE_RETURN], true);
    }

    /**
     * Returns true for movement types that reduce stock.
     */
    public function isOutgoing(): bool
    {
        return $this->movement_type === self::TYPE_OUT;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function warehouseDocument(): BelongsTo
    {
        return $this->belongsTo(WarehouseDocument::class);
    }

    public function sale(): BelongsTo
    {
        return $this->belongsTo(Sale::class);
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function productSize(): BelongsTo
    {
        return $this->belongsTo(ProductSize::class);
    }
}
