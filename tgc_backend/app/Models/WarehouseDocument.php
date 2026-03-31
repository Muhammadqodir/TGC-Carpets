<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Str;

class WarehouseDocument extends Model
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
        'external_uuid',
        'type',
        'client_id',
        'user_id',
        'document_date',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'document_date' => 'datetime',
        ];
    }

    protected static function boot(): void
    {
        parent::boot();

        static::creating(function (WarehouseDocument $document): void {
            if (empty($document->uuid)) {
                $document->uuid = (string) Str::uuid();
            }
        });
    }

    // ── Type helpers ──────────────────────────────────────────────────────────

    public function isIncoming(): bool
    {
        return in_array($this->type, [self::TYPE_IN, self::TYPE_RETURN], true);
    }

    public function isOutgoing(): bool
    {
        return $this->type === self::TYPE_OUT;
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
        return $this->hasMany(WarehouseDocumentItem::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(WarehouseDocumentPhoto::class);
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }
}
