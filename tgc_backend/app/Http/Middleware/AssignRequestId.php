<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Tags every request with a UUID before it reaches a controller, so every
 * audit_log row written during that request (Shipment + ShipmentItems +
 * StockMovements, for one save) can be tied back together — "one act by
 * one person at one moment" — and echoes it back as X-Request-Id so a
 * user reporting a problem can hand over the exact id. See
 * instructions/phase-3/06-audit-log.md.
 */
class AssignRequestId
{
    public function handle(Request $request, Closure $next): Response
    {
        $id = (string) Str::uuid();
        $request->attributes->set('request_id', $id);
        Log::withContext(['request_id' => $id]);

        $response = $next($request);
        $response->headers->set('X-Request-Id', $id);

        return $response;
    }
}
