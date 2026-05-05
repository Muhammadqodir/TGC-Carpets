<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreAppReleaseRequest;
use App\Models\AppRelease;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\View\View;

class AppReleaseController extends Controller
{
    // ── Auth ──────────────────────────────────────────────────────────────────

    public function showLogin(): View|RedirectResponse
    {
        if (Auth::check()) {
            return redirect()->route('admin.app-releases.index');
        }

        return view('admin.app-releases.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::attempt(['email' => $credentials['email'], 'password' => $credentials['password']], false)) {
            return back()
                ->withErrors(['email' => 'Login yoki parol noto\'g\'ri.'])
                ->onlyInput('email');
        }

        // Verify admin role — reject and log out if insufficient
        /** @var \App\Models\User $user */
        $user = Auth::user();

        if (! $user->hasRole('admin')) {
            Auth::logout();

            return back()
                ->withErrors(['email' => 'Bu panelga kirish uchun admin huquqi talab qilinadi.'])
                ->onlyInput('email');
        }

        $request->session()->regenerate();

        return redirect()->route('admin.app-releases.index');
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.app-releases.login');
    }

    // ── CRUD ──────────────────────────────────────────────────────────────────

    public function index(): View
    {
        $releases = AppRelease::with('creator')
            ->orderByDesc('id')
            ->paginate(20);

        return view('admin.app-releases.index', compact('releases'));
    }

    public function create(): View
    {
        return view('admin.app-releases.create');
    }

    public function store(StoreAppReleaseRequest $request): RedirectResponse
    {
        $platform = $request->input('platform');
        $ext      = $platform === 'android' ? 'apk' : 'exe';

        // Use a UUID to prevent enumeration of download URLs
        $filename = "{$platform}-" . Str::uuid() . ".{$ext}";

        /** @var \Illuminate\Http\UploadedFile $uploadedFile */
        $uploadedFile = $request->file('file');
        $storedPath   = $uploadedFile->storeAs('releases', $filename, 'public');

        // Compute SHA-256 server-side — never trust client-supplied hashes
        $sha256 = hash_file('sha256', Storage::disk('public')->path($storedPath));

        AppRelease::create([
            'platform'    => $platform,
            'version'     => $request->input('version'),
            'build_code'  => (int) $request->input('build_code'),
            'is_required' => $request->boolean('is_required'),
            'file_path'   => $storedPath,
            'sha256'      => $sha256,
            'changelog'   => $request->input('changelog'),
            'created_by'  => Auth::id(),
        ]);

        return redirect()
            ->route('admin.app-releases.index')
            ->with('success', 'Yangi versiya muvaffaqiyatli yuklandi.');
    }

    public function destroy(AppRelease $appRelease): RedirectResponse
    {
        Storage::disk('public')->delete($appRelease->file_path);
        $appRelease->delete();

        return redirect()
            ->route('admin.app-releases.index')
            ->with('success', "Versiya {$appRelease->version} ({$appRelease->platform}) o'chirildi.");
    }
}
