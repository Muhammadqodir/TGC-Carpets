<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Read-only. The first consumer of this table is a developer answering a
 * client dispute ("what did we quote them"), so a filterable JSON endpoint
 * is enough — no UI in this pass. Admin-only, the same narrow exception
 * to the dropped role-middleware rollout (phase-1 step 09) that phase-2
 * used for /analytics/production/compare: gates this one new diagnostic
 * route, applies `role:` nowhere else. See
 * instructions/phase-3/06-audit-log.md.
 */
class AuditLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $entries = AuditLog::query()
            ->when($request->filled('auditable_type'), fn ($q) => $q->where('auditable_type', $request->string('auditable_type')))
            ->when($request->filled('auditable_id'), fn ($q) => $q->where('auditable_id', $request->integer('auditable_id')))
            ->when($request->filled('user_id'), fn ($q) => $q->where('user_id', $request->integer('user_id')))
            ->when($request->filled('request_id'), fn ($q) => $q->where('request_id', $request->string('request_id')))
            ->when($request->filled('from'), fn ($q) => $q->where('created_at', '>=', $request->date('from')))
            ->when($request->filled('to'), fn ($q) => $q->where('created_at', '<=', $request->date('to')))
            ->latest('created_at')
            ->paginate($this->perPage($request));

        $userNames = User::whereIn('id', $entries->pluck('user_id')->filter()->unique())
            ->pluck('name', 'id');

        $entries->getCollection()->transform(fn (AuditLog $entry) => [
            'id'              => $entry->id,
            'auditable_type'  => class_basename($entry->auditable_type),
            'auditable_id'    => $entry->auditable_id,
            'event'           => $entry->event,
            'user_id'         => $entry->user_id,
            'user_name'       => $entry->user_id ? ($userNames[$entry->user_id] ?? null) : null,
            'old_values'      => $entry->old_values,
            'new_values'      => $entry->new_values,
            'request_id'      => $entry->request_id,
            'ip_address'      => $entry->ip_address,
            'url'             => $entry->url,
            'created_at'      => $entry->created_at?->toISOString(),
        ]);

        return response()->json($entries);
    }
}
