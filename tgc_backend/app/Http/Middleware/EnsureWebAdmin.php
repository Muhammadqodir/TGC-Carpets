<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Web-facing admin guard.
 *
 * Must be used AFTER the built-in `auth` middleware (which ensures a session
 * exists).  Aborts with 403 if the authenticated user does not have the
 * `admin` role.
 */
class EnsureWebAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        /** @var User|null $user */
        $user = $request->user();

        if (! $user?->hasRole(User::ROLE_ADMIN)) {
            abort(403, 'Bu sahifaga kirish uchun admin huquqi talab qilinadi.');
        }

        return $next($request);
    }
}
