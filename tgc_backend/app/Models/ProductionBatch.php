<?php

namespace App\Models;

use App\Models\ProductionBatchItem;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductionBatch extends Model
{
    use HasFactory;

    const TYPE_BY_ORDER  = 'by_order';
    const TYPE_FOR_STOCK = 'for_stock';
    const TYPE_MIXED     = 'mixed';

    const TYPES = [
        self::TYPE_BY_ORDER,
        self::TYPE_FOR_STOCK,
        self::TYPE_MIXED,
    ];

    const STATUS_PLANNED     = 'planned';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_COMPLETED   = 'completed';
    const STATUS_CANCELLED   = 'cancelled';

    const STATUSES = [
        self::STATUS_PLANNED,
        self::STATUS_IN_PROGRESS,
        self::STATUS_COMPLETED,
        self::STATUS_CANCELLED,
    ];

    protected $fillable = [
        'batch_title',
        'planned_datetime',
        'started_datetime',
        'completed_datetime',
        'machine_id',
        'type',
        'status',
        'created_by',
        'notes',
    ];

    protected function casts(): array
    {
        return [
            'planned_datetime'   => 'datetime',
            'started_datetime'   => 'datetime',
            'completed_datetime' => 'datetime',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function machine(): BelongsTo
    {
        return $this->belongsTo(Machine::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function items(): HasMany
    {
        return $this->hasMany(ProductionBatchItem::class);
    }
}
