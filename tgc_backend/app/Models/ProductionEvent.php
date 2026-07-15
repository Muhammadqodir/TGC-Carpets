<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductionEvent extends Model
{
    const UPDATED_AT = null;   // append-only: rows are never updated

    const TYPE_PRODUCED   = 'produced';
    const TYPE_DEFECT     = 'defect';
    const TYPE_SCRAP      = 'scrap';
    const TYPE_CORRECTION = 'correction';

    /**
     * Which cache each event type feeds. Canonical mapping — see
     * instructions/phase-2/01-production-events-table.md.
     *
     *   produced_quantity == SUM(quantity) WHERE event_type IN (produced, scrap, correction)
     *   defect_quantity   == SUM(quantity) WHERE event_type = defect
     */
    const PRODUCED_TYPES = [self::TYPE_PRODUCED, self::TYPE_SCRAP, self::TYPE_CORRECTION];
    const DEFECT_TYPES   = [self::TYPE_DEFECT];

    protected $fillable = [
        'production_batch_item_id', 'event_type', 'quantity',
        'occurred_at', 'user_id', 'defect_document_id', 'idempotency_key', 'reason',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'quantity'    => 'integer',
            'occurred_at' => 'datetime',
        ];
    }

    public function productionBatchItem(): BelongsTo
    {
        return $this->belongsTo(ProductionBatchItem::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function defectDocument(): BelongsTo
    {
        return $this->belongsTo(DefectDocument::class);
    }
}
