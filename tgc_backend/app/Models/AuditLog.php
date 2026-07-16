<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Append-only. No SoftDeletes, no `updated_at`, and intentionally no
 * relationships that would tempt anything to read a balance from this
 * table — it is evidence for humans investigating a dispute, not a
 * second source of truth for any business fact. See
 * instructions/phase-3/06-audit-log.md.
 */
class AuditLog extends Model
{
    const UPDATED_AT = null;

    protected $table = 'audit_log';

    protected $fillable = [
        'auditable_type',
        'auditable_id',
        'event',
        'user_id',
        'old_values',
        'new_values',
        'request_id',
        'ip_address',
        'url',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'auditable_id' => 'integer',
            'user_id'      => 'integer',
            'old_values'   => 'array',
            'new_values'   => 'array',
            'created_at'   => 'datetime',
        ];
    }
}
