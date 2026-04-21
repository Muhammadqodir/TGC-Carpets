<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RawMaterialStockMovement extends Model
{
    const TYPE_RECEIVED = 'received';
    const TYPE_SPENT    = 'spent';

    const TYPES = [self::TYPE_RECEIVED, self::TYPE_SPENT];

    protected $fillable = [
        'material_id',
        'user_id',
        'date_time',
        'type',
        'quantity',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'date_time' => 'datetime',
            'quantity'  => 'float',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function material(): BelongsTo
    {
        return $this->belongsTo(RawMaterial::class, 'material_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
