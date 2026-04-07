<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Color extends Model
{
    protected $fillable = ['name'];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function productColors(): HasMany
    {
        return $this->hasMany(ProductColor::class);
    }
}
