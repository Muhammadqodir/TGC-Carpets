<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ClientController;
use App\Http\Controllers\Api\V1\ColorController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\EmployeeController;
use App\Http\Controllers\Api\V1\ProductColorController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ProductQualityController;
use App\Http\Controllers\Api\V1\ProductSizeController;
use App\Http\Controllers\Api\V1\ProductTypeController;
use App\Http\Controllers\Api\V1\ProductVariantController;
use App\Http\Controllers\Api\V1\SaleController;
use App\Http\Controllers\Api\V1\StockController;
use App\Http\Controllers\Api\V1\WarehouseDocumentController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — /api/v1/
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function (): void {

    // ── Public ────────────────────────────────────────────────────────────
    Route::prefix('auth')->name('auth.')->group(function (): void {
        Route::post('login', [AuthController::class, 'login'])->name('login');
    });

    // ── Authenticated ─────────────────────────────────────────────────────
    Route::middleware('auth:sanctum')->group(function (): void {

        // Auth
        Route::prefix('auth')->name('auth.')->group(function (): void {
            Route::post('logout',          [AuthController::class, 'logout'])->name('logout');
            Route::get('me',               [AuthController::class, 'me'])->name('me');
            Route::post('change-password', [AuthController::class, 'changePassword'])->name('change-password');
        });

        // Dashboard statistics
        Route::get('dashboard/stats', [DashboardController::class, 'stats'])->name('dashboard.stats');

        // Products  — admin + warehouse can write; seller read-only enforced via Policy later
        Route::apiResource('products', ProductController::class);

        // Product types (read-only reference list)
        Route::get('product-types', [ProductTypeController::class, 'index'])->name('product-types.index');

        // Product qualities
        Route::apiResource('product-qualities', ProductQualityController::class)->except(['show']);

        // Product sizes
        Route::apiResource('product-sizes', ProductSizeController::class);

        // Colors (reference list)
        Route::get('colors', [ColorController::class, 'index'])->name('colors.index');
        Route::post('colors', [ColorController::class, 'store'])->name('colors.store');

        // Product colors (color+image per product)
        Route::apiResource('product-colors', ProductColorController::class)->except(['show']);

        // Clients
        Route::apiResource('clients', ClientController::class);

        // Employees (users management)
        Route::apiResource('employees', EmployeeController::class);

        // Warehouse documents + photo sub-routes
        Route::apiResource('warehouse-documents', WarehouseDocumentController::class);
        Route::post(
            'warehouse-documents/{warehouseDocument}/photos',
            [WarehouseDocumentController::class, 'uploadPhoto']
        )->name('warehouse-documents.photos.store');
        Route::delete(
            'warehouse-documents/{warehouseDocument}/photos/{photoId}',
            [WarehouseDocumentController::class, 'deletePhoto']
        )->name('warehouse-documents.photos.destroy');

        // Sales
        Route::apiResource('sales', SaleController::class);

        // Stock (read-only — all authenticated roles)
        Route::prefix('stock')->name('stock.')->group(function (): void {
            Route::get('/',         [StockController::class, 'index'])->name('index');
            Route::get('movements', [StockController::class, 'movements'])->name('movements');
        });

        // Product variants (barcode lookup)
        Route::get('product-variants', [ProductVariantController::class, 'index'])->name('product-variants.index');
        Route::get('product-variants/barcode/{barcode}', [ProductVariantController::class, 'findByBarcode'])->name('product-variants.by-barcode');

    });

});
