<?php

use App\Http\Controllers\Admin\AppReleaseController;
use App\Http\Controllers\PdfPreviewController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

/*
|--------------------------------------------------------------------------
| Admin — App Release Manager
|--------------------------------------------------------------------------
| Accessible at /admin/app-releases
| Authentication: session-based (web guard) + admin role check
|--------------------------------------------------------------------------
*/
Route::prefix('admin/app-releases')->name('admin.app-releases.')->group(function (): void {

    // ── Guest routes ────────────────────────────────────────────────────────
    Route::get('login',  [AppReleaseController::class, 'showLogin'])->name('login');
    Route::post('login', [AppReleaseController::class, 'login'])->name('login.submit');

    // ── Authenticated + admin-role routes ───────────────────────────────────
    Route::middleware(['auth', 'web_admin'])->group(function (): void {
        Route::get('/',                      [AppReleaseController::class, 'index'])->name('index');
        Route::get('create',                 [AppReleaseController::class, 'create'])->name('create');
        Route::post('/',                     [AppReleaseController::class, 'store'])->name('store');
        Route::delete('{appRelease}',        [AppReleaseController::class, 'destroy'])->name('destroy');
        Route::post('logout',                [AppReleaseController::class, 'logout'])->name('logout');
    });
});

/*
|--------------------------------------------------------------------------
| PDF Design Previews (dev/staging only)
|--------------------------------------------------------------------------
| Open these URLs in the browser to design and iterate on PDF templates
| without generating an actual PDF file.
|
| Routes:
|   GET /pdf-preview/warehouse-document/{id?}
|   GET /pdf-preview/shipment-invoice/{id?}
|   GET /pdf-preview/shipment-hisob-faktura/{id?}
|
| Pass an explicit {id} to load a specific record, or omit it to use the
| first available record in the database.
*/
if (! app()->isProduction()) {
    Route::prefix('pdf-preview')->name('pdf-preview.')->group(function () {
        Route::get('warehouse-document/{id?}', [PdfPreviewController::class, 'warehouseDocument'])
            ->name('warehouse-document');

        Route::get('shipment-invoice/{id?}', [PdfPreviewController::class, 'shipmentInvoice'])
            ->name('shipment-invoice');

        Route::get('shipment-hisob-faktura/{id?}', [PdfPreviewController::class, 'shipmentHisobFaktura'])
            ->name('shipment-hisob-faktura');
    });
}
