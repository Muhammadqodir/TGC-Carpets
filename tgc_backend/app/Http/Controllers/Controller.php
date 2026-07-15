<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

abstract class Controller
{
    /**
     * Resolve a per_page value, clamped to a sane range.
     * Guards against ?per_page=1000000 taking the server down.
     */
    protected function perPage(Request $request, int $default = 50, int $max = 200): int
    {
        $value = $request->integer('per_page', $default);

        return max(1, min($value, $max));
    }
}
