<?php

namespace App\Models;

use App\Models\ProductionBatch;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Machine extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'model_name',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productionBatches(): HasMany
    {
        return $this->hasMany(ProductionBatch::class);
    }
}
