<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WarehouseDocumentPhoto extends Model
{
    use HasFactory;

    protected $fillable = [
        'warehouse_document_id',
        'path',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function warehouseDocument(): BelongsTo
    {
        return $this->belongsTo(WarehouseDocument::class);
    }
}
