<?php

namespace App\Observers;

use App\Models\AuditLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

/**
 * Writes one audit_log row per Eloquent create/update/delete/restore on a
 * registered model — see AppServiceProvider::boot(). Synchronous and
 * inside the same transaction as the business write on purpose: an audit
 * log that can silently fail or drop rows under a queue is worse than
 * none, because it will be trusted. See
 * instructions/phase-3/06-audit-log.md.
 *
 * Does NOT fire on query-builder writes (`Model::query()->update([...])`,
 * `$relation->delete()` as a bulk operation) — those bypass Eloquent
 * events entirely. Known gap: ProductionBatchService::update()'s
 * `$batch->items()->delete()` and the bulk `Order::whereIn(...)->update()`
 * calls produce no audit rows. Accepted per the instruction file rather
 * than converted to per-model loops, which would add a write per row on
 * otherwise-fine bulk operations.
 */
class AuditableObserver
{
    public function created(Model $model): void
    {
        $this->log($model, 'created');
    }

    public function updated(Model $model): void
    {
        $this->log($model, 'updated');
    }

    public function deleted(Model $model): void
    {
        $this->log($model, 'deleted');
    }

    public function restored(Model $model): void
    {
        $this->log($model, 'restored');
    }

    private function log(Model $model, string $event): void
    {
        $changes = $model->getChanges();
        unset($changes['updated_at']);

        if ($event === 'updated' && $changes === []) {
            return; // a touch with no real change is not worth a row
        }

        // A hard delete's getChanges() is empty (nothing was "changed", the
        // row is gone), so the only chance to keep what it was is the
        // original attribute set — most relevant for Payment, which has no
        // SoftDeletes and today loses the record entirely on DELETE.
        $oldValues = match ($event) {
            'created' => null,
            'deleted' => $model->getOriginal(),
            default   => Arr::only($model->getOriginal(), array_keys($changes)),
        };

        AuditLog::create([
            'auditable_type' => $model::class,
            'auditable_id'   => $model->getKey(),
            'event'          => $event,
            'user_id'        => auth()->id(),
            'old_values'     => $oldValues,
            'new_values'     => $event === 'deleted' ? null : $changes,
            'request_id'     => request()->attributes->get('request_id'),
            'ip_address'     => request()->ip(),
            'url'            => Str::limit(request()->fullUrl(), 500, ''),
            'created_at'     => now(),
        ]);
    }
}
