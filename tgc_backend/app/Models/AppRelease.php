<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AppRelease extends Model
{
    protected $fillable = [
        'platform',
        'version',
        'build_code',
        'is_required',
        'file_path',
        'sha256',
        'changelog',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'is_required' => 'boolean',
            'build_code'  => 'integer',
        ];
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Returns the publicly accessible download URL for this release file.
     * Requires `php artisan storage:link` to have been run on the server.
     */
    public function getDownloadUrl(): string
    {
        // url('storage/...') works after php artisan storage:link creates
        // the public/storage symlink pointing to storage/app/public
        return url('storage/' . $this->file_path);
    }
}
