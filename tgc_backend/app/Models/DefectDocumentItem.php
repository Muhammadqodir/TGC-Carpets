<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DefectDocumentItem extends Model
{
    use HasFactory;

    protected $fillable = [
        'defect_document_id',
        'production_batch_item_id',
        'quantity',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function defectDocument(): BelongsTo
    {
        return $this->belongsTo(DefectDocument::class);
    }

    public function productionBatchItem(): BelongsTo
    {
        return $this->belongsTo(ProductionBatchItem::class);
    }
}
