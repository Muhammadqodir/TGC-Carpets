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

    const DIRECTION_IN  = 'in';
    const DIRECTION_OUT = 'out';

    protected $fillable = [
        'uuid',
        'external_uuid',
        'type',
        'direction',
        'user_id',
        'document_date',
        'notes',
        'pdf_path',
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

    /**
     * The single source of truth for which way this document moves stock.
     * Used by WarehouseDocumentService::syncItems() to pick the
     * StockMovement type, and by isIncoming()/isOutgoing() below — so
     * those two can never disagree with what actually gets written to the
     * ledger. See instructions/phase-3/05-signed-adjustment-documents.md.
     *
     * 'adjustment' has no direction of its own in the type; it borrows the
     * `direction` column, which is required at validation time for that
     * type and otherwise NULL. A NULL direction on an adjustment defaults
     * to 'in' so an old client that has not yet been updated to send
     * `direction` keeps behaving exactly as before (unconditional TYPE_IN).
     */
    public function movementType(): string
    {
        return self::resolveMovementType($this->type, $this->direction);
    }

    /**
     * Static so WarehouseDocumentService::create() can run the
     * insufficient-stock check against raw request data, before a
     * WarehouseDocument row (and therefore a model instance) exists.
     */
    public static function resolveMovementType(string $type, ?string $direction): string
    {
        return match ($type) {
            self::TYPE_IN, self::TYPE_RETURN => StockMovement::TYPE_IN,
            self::TYPE_OUT                   => StockMovement::TYPE_OUT,
            self::TYPE_ADJUSTMENT            => $direction === self::DIRECTION_OUT
                ? StockMovement::TYPE_OUT
                : StockMovement::TYPE_IN,
        };
    }

    /**
     * A document that reduces physical stock and must therefore be
     * checked against available stock before it is allowed to save —
     * every TYPE_OUT document, and an adjustment with direction 'out'.
     */
    public function reducesStock(): bool
    {
        return $this->movementType() === StockMovement::TYPE_OUT;
    }

    public function isIncoming(): bool
    {
        return $this->movementType() === StockMovement::TYPE_IN;
    }

    public function isOutgoing(): bool
    {
        return $this->movementType() === StockMovement::TYPE_OUT;
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(WarehouseDocumentItem::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(WarehouseDocumentPhoto::class);
    }
}
