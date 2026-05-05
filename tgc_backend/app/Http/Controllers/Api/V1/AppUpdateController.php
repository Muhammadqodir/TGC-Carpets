<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppRelease;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Public endpoint — no authentication required.
 *
 * GET /api/app-updates/latest?platform=android&current_version=22
 *
 * Returns the latest release for the given platform.
 * The client compares the returned build_code with its own to decide
 * whether an update is needed.
 */
class AppUpdateController extends Controller
{
    public function latest(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'platform'        => ['required', 'in:android,windows'],
            'current_version' => ['sometimes', 'integer', 'min:0'],
        ]);

        $release = AppRelease::where('platform', $validated['platform'])
            ->orderByDesc('build_code')
            ->first();

        if (! $release) {
            return response()->json(
                ['message' => 'No releases found for this platform.'],
                404,
            );
        }

        return response()->json([
            'version'    => $release->version,
            'build_code' => $release->build_code,
            'required'   => $release->is_required,
            'url'        => $release->getDownloadUrl(),
            'sha256'     => $release->sha256,
            'changelog'  => $release->changelog,
        ]);
    }
}
