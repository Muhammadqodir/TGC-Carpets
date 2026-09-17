<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** A label printed for an already-counted carpet — see the create_label_reprints_table migration. */
class LabelReprint extends Model
{
    const REASON_REPRINT     = 'reprint';
    const REASON_OVER_TARGET = 'over_target';

    protected $fillable = [
        'production_batch_item_id',
        'printed_by',
        'printed_at',
        'reason',
        'idempotency_key',
    ];

    protected function casts(): array
    {
        return [
            'printed_at' => 'datetime',
        ];
    }

    public function batchItem(): BelongsTo
    {
        return $this->belongsTo(ProductionBatchItem::class, 'production_batch_item_id');
    }

    public function printedByUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'printed_by');
    }
}
