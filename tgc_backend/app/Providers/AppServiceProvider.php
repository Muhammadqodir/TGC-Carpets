<?php

namespace App\Providers;

use App\Models\DefectDocument;
use App\Models\DefectDocumentItem;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\Shipment;
use App\Models\ShipmentItem;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use App\Observers\AuditableObserver;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Registered per-model rather than globally — auditing every write in
     * the app (lookup tables, colours, sizes) would drown the signal. See
     * instructions/phase-3/06-audit-log.md.
     */
    private const AUDITED_MODELS = [
        Payment::class,
        Shipment::class,
        ShipmentItem::class,
        WarehouseDocument::class,
        WarehouseDocumentItem::class,
        StockMovement::class,
        Order::class,
        OrderItem::class,
        ProductionBatch::class,
        ProductionBatchItem::class,
        DefectDocument::class,
        DefectDocumentItem::class,
    ];

    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        foreach (self::AUDITED_MODELS as $model) {
            $model::observe(AuditableObserver::class);
        }
    }
}
