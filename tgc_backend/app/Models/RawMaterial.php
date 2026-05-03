<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\RawMaterialStockMovement;

class RawMaterial extends Model
{
    const UNIT_PIECE = 'piece';
    const UNIT_SQM   = 'sqm';
    const UNIT_KG    = 'kg';
    const UNIT_METER = 'meter';

    const UNITS = [self::UNIT_PIECE, self::UNIT_SQM, self::UNIT_KG, self::UNIT_METER];

    protected $fillable = ['name', 'type', 'unit'];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function stockMovements(): HasMany
    {
        return $this->hasMany(RawMaterialStockMovement::class, 'material_id');
    }
}
