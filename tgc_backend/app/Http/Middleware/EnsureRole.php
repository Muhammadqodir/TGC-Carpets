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
        // users.role is an array cast — a user can hold several roles, and
        // the seeder writes ['admin']. The previous check compared that array
        // against the string list with in_array(..., true), which is never
        // true, so this middleware denied EVERYONE including admins. Use the
        // model's own helper, which already normalises the value.
        $userRoles = $request->user()?->getRoles() ?? [];

        if (array_intersect($userRoles, $roles) === []) {
            return response()->json(
                ['message' => 'Forbidden. Insufficient role.'],
                Response::HTTP_FORBIDDEN,
            );
        }

        return $next($request);
    }
}
