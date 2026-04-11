<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DefectDocumentPhoto extends Model
{
    use HasFactory;

    protected $fillable = [
        'defect_document_id',
        'path',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function defectDocument(): BelongsTo
    {
        return $this->belongsTo(DefectDocument::class);
    }
}
