<?php

use App\Http\Controllers\Api\V1\AppUpdateController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\ClientController;
use App\Http\Controllers\Api\V1\ClientDebitController;
use App\Http\Controllers\Api\V1\ColorController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\ProductEdgeController;
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
use App\Http\Controllers\Api\V1\RawMaterialController;
use App\Http\Controllers\Api\V1\StockController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\ShipmentController;
use App\Http\Controllers\Api\V1\WarehouseDocumentController;
use App\Http\Controllers\Api\V1\ShipmentImportController;
use App\Http\Controllers\Api\V1\WarehouseImportController;
use App\Http\Controllers\Api\V1\ProductAnalyticsController;
use App\Http\Controllers\Api\V1\ProductionAnalyticsController;
use App\Http\Controllers\Api\V1\ProductImportController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — /api/v1/
|--------------------------------------------------------------------------
*/

// ── Public app-update check (outside /v1/ to stay platform-version-agnostic) ──
// Rate-limited to 30 requests per minute per IP.
Route::middleware('throttle:30,1')->group(function (): void {
    Route::get('app-updates/latest', [AppUpdateController::class, 'latest'])
        ->name('app-updates.latest');
});

Route::prefix('v1')->group(function (): void {

    // ── Public ────────────────────────────────────────────────────────────
    Route::prefix('auth')->name('auth.')->group(function (): void {
        Route::post('login', [AuthController::class, 'login'])->name('login');
        Route::get('label-managers', [AuthController::class, 'labelManagers'])->name('label-managers');
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

        // Audit log — admin-only. See instructions/phase-3/06-audit-log.md.
        Route::get('audit-log', [AuditLogController::class, 'index'])
            ->middleware('role:admin')
            ->name('audit-log.index');

        // Product Analytics
        Route::get('analytics/products',     [ProductAnalyticsController::class, 'index'])->name('analytics.products');
        Route::get('analytics/top-products', [ProductAnalyticsController::class, 'topProducts'])->name('analytics.top-products');

        // Production Analytics (produced items statistics)
        Route::get('analytics/production', [ProductionAnalyticsController::class, 'index'])->name('analytics.production');
        // Phase 2 step 04 rollout tool — legacy vs event-sourced numbers, admin-only.
        // Temporary: remove along with the legacy path once ANALYTICS_SOURCE=events
        // has shipped and been confirmed. See instructions/phase-2/04.
        Route::get('analytics/production/compare', [ProductionAnalyticsController::class, 'compare'])
            ->middleware('role:admin')
            ->name('analytics.production.compare');

        // Products  — admin + warehouse can write; seller read-only enforced via Policy later
        // Literal sub-routes must be declared before apiResource to avoid {product} capture.
        Route::post('products/import', [ProductImportController::class, 'store'])->name('products.import');
        Route::apiResource('products', ProductController::class);

        // Product types
        Route::get('product-types/{productType}/usage', [ProductTypeController::class, 'usage']);
        Route::post('product-types/{productType}/archive', [ProductTypeController::class, 'archive']);
        Route::post('product-types/{productType}/unarchive', [ProductTypeController::class, 'unarchive']);
        Route::apiResource('product-types', ProductTypeController::class)->except(['show']);

        // Product qualities
        Route::get('product-qualities/{productQuality}/usage', [ProductQualityController::class, 'usage']);
        Route::post('product-qualities/{productQuality}/archive', [ProductQualityController::class, 'archive']);
        Route::post('product-qualities/{productQuality}/unarchive', [ProductQualityController::class, 'unarchive']);
        Route::apiResource('product-qualities', ProductQualityController::class)->except(['show']);

        // Product edges
        Route::get('product-edges/{productEdge}/usage', [ProductEdgeController::class, 'usage']);
        Route::apiResource('product-edges', ProductEdgeController::class)->except(['show']);

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

        // Warehouse import (step-by-step: clients → qualities → items)
        Route::get('warehouse-import/clients',   [WarehouseImportController::class, 'clients'])->name('warehouse-import.clients');
        Route::get('warehouse-import/qualities', [WarehouseImportController::class, 'qualities'])->name('warehouse-import.qualities');
        Route::get('warehouse-import/items',     [WarehouseImportController::class, 'items'])->name('warehouse-import.items');

        Route::get('shipment-import/clients',    [ShipmentImportController::class, 'clients'])->name('shipment-import.clients');
        Route::get('shipment-import/qualities',  [ShipmentImportController::class, 'qualities'])->name('shipment-import.qualities');
        Route::get('shipment-import/items',      [ShipmentImportController::class, 'items'])->name('shipment-import.items');

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
        Route::get('production-batches-scan', [ProductionBatchController::class, 'scanItem'])
            ->name('production-batches.scan');
        Route::get('production-batches/{productionBatch}/items/{item}', [ProductionBatchController::class, 'showItem'])
            ->name('production-batches.items.show');
        Route::post('production-batches/{productionBatch}/items/{item}/print-label', [ProductionBatchController::class, 'printLabel'])
            ->name('production-batches.items.print-label');
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

        // Raw Materials Warehouse
        Route::prefix('raw-materials')->name('raw-materials.')->group(function (): void {
            // Literal sub-routes must precede the apiResource wildcard
            Route::get('movements',              [RawMaterialController::class, 'movements'])->name('movements.index');
            Route::post('movements/batch',       [RawMaterialController::class, 'storeBatchMovement'])->name('movements.batch');
        });
        Route::apiResource('raw-materials', RawMaterialController::class);

    });

});
