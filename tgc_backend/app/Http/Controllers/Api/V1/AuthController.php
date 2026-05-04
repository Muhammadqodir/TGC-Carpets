<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    /**
     * Issue a Sanctum API token.
     *
     * POST /api/v1/auth/login
     */
    public function login(LoginRequest $request): JsonResponse
    {
        if (! Auth::attempt($request->only('email', 'password'))) {
            return response()->json(
                ['message' => 'The provided credentials are incorrect.'],
                401,
            );
        }

        $user  = Auth::user();
        $token = $user->createToken('api-token')->plainTextToken;

        return response()->json([
            'data' => [
                'user'  => $this->formatUser($user),
                'token' => $token,
            ],
        ]);
    }

    /**
     * Revoke the current access token.
     *
     * POST /api/v1/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out successfully.']);
    }

    /**
     * Return the authenticated user with role context.
     *
     * GET /api/v1/auth/me
     */
    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $this->formatUser($request->user()),
        ]);
    }

    /**
     * Change the authenticated user's password.
     *
     * POST /api/v1/auth/change-password
     */
    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => ['required', 'string'],
            'new_password'     => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = $request->user();

        if (! Hash::check($request->current_password, $user->password)) {
            return response()->json(
                ['message' => 'Joriy parol noto\'g\'ri.'],
                422,
            );
        }

        $user->update(['password' => Hash::make($request->new_password)]);

        return response()->json(['message' => 'Parol muvaffaqiyatli o\'zgartirildi.']);
    }

    /**
     * Get list of label managers for label printing terminal login.
     * Public endpoint (no auth required).
     *
     * GET /api/v1/auth/label-managers
     */
    public function labelManagers(): JsonResponse
    {
        $labelManagers = \App\Models\User::whereJsonContains('role', 'label_manager')
            ->orderBy('name')
            ->get()
            ->map(function ($user) {
                return [
                    'id'    => $user->id,
                    'name'  => $user->name,
                    'email' => $user->email,
                    'role'  => $user->getRoles(),
                ];
            });

        return response()->json(['data' => $labelManagers]);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function formatUser(\App\Models\User $user): array
    {
        return [
            'id'           => $user->id,
            'name'         => $user->name,
            'email'        => $user->email,
            'phone'        => $user->phone,
            'role'         => $user->getRoles(),
            'is_admin'     => $user->isAdmin(),
            'is_warehouse' => $user->isWarehouse(),
            'is_seller'    => $user->isSeller(),
        ];
    }
}
