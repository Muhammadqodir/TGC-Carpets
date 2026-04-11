<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DefectDocument extends Model
{
    use HasFactory;

    protected $fillable = [
        'production_batch_id',
        'user_id',
        'datetime',
        'description',
    ];

    protected function casts(): array
    {
        return [
            'datetime' => 'datetime',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productionBatch(): BelongsTo
    {
        return $this->belongsTo(ProductionBatch::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(DefectDocumentItem::class);
    }

    public function photos(): HasMany
    {
        return $this->hasMany(DefectDocumentPhoto::class);
    }
}
