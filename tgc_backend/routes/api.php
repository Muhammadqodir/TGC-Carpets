<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ClientController;
use App\Http\Controllers\Api\V1\ClientDebitController;
use App\Http\Controllers\Api\V1\ColorController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\EmployeeController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\ProductColorController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ProductQualityController;
use App\Http\Controllers\Api\V1\ProductSizeController;
use App\Http\Controllers\Api\V1\ProductTypeController;
use App\Http\Controllers\Api\V1\ProductVariantController;
use App\Http\Controllers\Api\V1\MachineController;
use App\Http\Controllers\Api\V1\DefectDocumentController;
use App\Http\Controllers\Api\V1\ProductionBatchController;
use App\Http\Controllers\Api\V1\StockController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\ShipmentController;
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

        // Product types
        Route::get('product-types/{productType}/usage', [ProductTypeController::class, 'usage']);
        Route::apiResource('product-types', ProductTypeController::class)->except(['show']);

        // Product qualities
        Route::get('product-qualities/{productQuality}/usage', [ProductQualityController::class, 'usage']);
        Route::apiResource('product-qualities', ProductQualityController::class)->except(['show']);

        // Product sizes
        Route::get('product-sizes/{productSize}/usage', [ProductSizeController::class, 'usage']);
        Route::apiResource('product-sizes', ProductSizeController::class);

        // Colors
        Route::get('colors/{color}/usage', [ColorController::class, 'usage']);
        Route::apiResource('colors', ColorController::class)->except(['show']);

        // Product colors (color+image per product)
        Route::apiResource('product-colors', ProductColorController::class)->except(['show']);

        // Clients
        // NOTE: literal /clients/debits must be declared before the apiResource wildcard
        Route::get('clients/debits',                [ClientDebitController::class, 'index'])->name('clients.debits.index');
        Route::get('clients/{client}/debit-ledger', [ClientDebitController::class, 'ledger'])->name('clients.debit-ledger');
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

        // Stock (read-only — all authenticated roles)
        Route::prefix('stock')->name('stock.')->group(function (): void {
            Route::get('/',         [StockController::class, 'index'])->name('index');
            Route::get('variants',  [StockController::class, 'variants'])->name('variants');
            Route::get('movements', [StockController::class, 'movements'])->name('movements');
        });

        // Product variants (barcode lookup)
        Route::get('product-variants', [ProductVariantController::class, 'index'])->name('product-variants.index');
        Route::get('product-variants/barcode/{barcode}', [ProductVariantController::class, 'findByBarcode'])->name('product-variants.by-barcode');

        // Orders
        Route::apiResource('orders', OrderController::class);

        // Shipments
        Route::get('shipments/orders-for-shipment', [ShipmentController::class, 'ordersForShipment'])->name('shipments.orders-for-shipment');
        Route::get('shipments/last-price', [ShipmentController::class, 'lastPrice'])->name('shipments.last-price');
        Route::post('shipments', [ShipmentController::class, 'store'])->name('shipments.store');
        Route::get('shipments', [ShipmentController::class, 'index'])->name('shipments.index');
        Route::get('shipments/{shipment}', [ShipmentController::class, 'show'])->name('shipments.show');

        // Machines
        Route::apiResource('machines', MachineController::class);

        // Production Batches
        Route::apiResource('production-batches', ProductionBatchController::class);
        Route::get('production-batches-order-items', [ProductionBatchController::class, 'orderItemsAvailable'])
            ->name('production-batches.order-items');
        Route::get('production-batches-labeling-items', [ProductionBatchController::class, 'labelingItems'])
            ->name('production-batches.labeling-items');
        Route::get('production-batches/{productionBatch}/items/{item}', [ProductionBatchController::class, 'showItem'])
            ->name('production-batches.items.show');
        Route::post('production-batches/{productionBatch}/items/{item}/print-label', [ProductionBatchController::class, 'printLabel'])
            ->name('production-batches.items.print-label');
        Route::post('production-batches/{productionBatch}/start', [ProductionBatchController::class, 'start'])
            ->name('production-batches.start');
        Route::post('production-batches/{productionBatch}/complete', [ProductionBatchController::class, 'complete'])
            ->name('production-batches.complete');
        Route::post('production-batches/{productionBatch}/cancel', [ProductionBatchController::class, 'cancel'])
            ->name('production-batches.cancel');
        Route::patch('production-batches/{productionBatch}/items/{item}', [ProductionBatchController::class, 'updateItem'])
            ->name('production-batches.items.update');

        // Defect Documents (nested under production batch + standalone show/delete)
        Route::get('production-batches/{productionBatch}/defect-documents', [DefectDocumentController::class, 'index'])
            ->name('production-batches.defect-documents.index');
        Route::post('production-batches/{productionBatch}/defect-documents', [DefectDocumentController::class, 'store'])
            ->name('production-batches.defect-documents.store');
        Route::get('defect-documents/{defectDocument}', [DefectDocumentController::class, 'show'])
            ->name('defect-documents.show');
        Route::delete('defect-documents/{defectDocument}', [DefectDocumentController::class, 'destroy'])
            ->name('defect-documents.destroy');

        // Payments
        Route::get('payments',           [PaymentController::class, 'index'])->name('payments.index');
        Route::post('payments',          [PaymentController::class, 'store'])->name('payments.store');
        Route::get('payments/{payment}', [PaymentController::class, 'show'])->name('payments.show');
        Route::delete('payments/{payment}', [PaymentController::class, 'destroy'])->name('payments.destroy');

        // Shipments (read-only list + show)
        Route::get('shipments',          [ShipmentController::class, 'index'])->name('shipments.index');
        Route::get('shipments/{shipment}', [ShipmentController::class, 'show'])->name('shipments.show');

    });

});
