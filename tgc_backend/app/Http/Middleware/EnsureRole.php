<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gate middleware for role-based access on API routes.
 *
 * Usage (single role):   ->middleware('role:admin')
 * Usage (multiple roles): ->middleware('role:admin,warehouse')
 */
class EnsureRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        if (! in_array($request->user()?->role, $roles, true)) {
            return response()->json(
                ['message' => 'Forbidden. Insufficient role.'],
                Response::HTTP_FORBIDDEN,
            );
        }

        return $next($request);
    }
}
