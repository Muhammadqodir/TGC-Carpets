<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Register role guard middleware — used as 'role:admin', 'role:admin,warehouse', etc.
        $middleware->alias([
            'role'      => \App\Http\Middleware\EnsureRole::class,
            // Used by the admin web panel to verify the `admin` role after session auth
            'web_admin' => \App\Http\Middleware\EnsureWebAdmin::class,
        ]);

        // Redirect unauthenticated web users to the admin panel login page
        $middleware->redirectGuestsTo(fn () => route('admin.app-releases.login'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
