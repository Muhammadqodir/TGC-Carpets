<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\DefectDocument;
use App\Models\Order;
use App\Models\Payment;
use App\Models\ProductionBatch;
use App\Models\Shipment;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AnalyticsController extends Controller
{
    /**
     * GET /api/v1/analytics/overview
     *
     * Returns comprehensive analytics overview for a given date range.
     */
    public function overview(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to = $request->input('to', now()->endOfMonth()->toDateString());

        $data = [
            'sales' => $this->getSalesAnalytics($from, $to),
            'production' => $this->getProductionAnalytics($from, $to),
            'warehouse' => $this->getWarehouseAnalytics($from, $to),
            'financial' => $this->getFinancialAnalytics($from, $to),
            'orders' => $this->getOrderAnalytics($from, $to),
            'date_from' => $from,
            'date_to' => $to,
        ];

        return response()->json(['data' => $data]);
    }

    /**
     * GET /api/v1/analytics/sales
     *
     * Returns detailed sales analytics.
     */
    public function sales(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to = $request->input('to', now()->endOfMonth()->toDateString());

        $data = $this->getSalesAnalytics($from, $to);
        $data['date_from'] = $from;
        $data['date_to'] = $to;

        return response()->json(['data' => $data]);
    }

    /**
     * GET /api/v1/analytics/production
     *
     * Returns detailed production analytics.
     */
    public function production(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to = $request->input('to', now()->endOfMonth()->toDateString());

        $data = $this->getProductionAnalytics($from, $to);
        $data['date_from'] = $from;
        $data['date_to'] = $to;

        return response()->json(['data' => $data]);
    }

    /**
     * GET /api/v1/analytics/warehouse
     *
     * Returns detailed warehouse analytics.
     */
    public function warehouse(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to = $request->input('to', now()->endOfMonth()->toDateString());

        $data = $this->getWarehouseAnalytics($from, $to);
        $data['date_from'] = $from;
        $data['date_to'] = $to;

        return response()->json(['data' => $data]);
    }

    /**
     * GET /api/v1/analytics/financial
     *
     * Returns detailed financial analytics.
     */
    public function financial(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to = $request->input('to', now()->endOfMonth()->toDateString());

        $data = $this->getFinancialAnalytics($from, $to);
        $data['date_from'] = $from;
        $data['date_to'] = $to;

        return response()->json(['data' => $data]);
    }

    /**
     * GET /api/v1/analytics/clients
     *
     * Returns detailed client analytics.
     */
    public function clients(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to = $request->input('to', now()->endOfMonth()->toDateString());
        $limit = $request->input('limit', 10);

        // Top clients by revenue
        $topClients = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->join('clients', 'clients.id', '=', 'shipments.client_id')
            ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
            ->select(
                'clients.id',
                'clients.contact_name',
                'clients.shop_name',
                'clients.region',
                DB::raw('SUM(shipment_items.total) as total_revenue'),
                DB::raw('COUNT(DISTINCT shipments.id) as shipment_count'),
                DB::raw('SUM(shipment_items.quantity) as total_quantity')
            )
            ->groupBy('clients.id', 'clients.contact_name', 'clients.shop_name', 'clients.region')
            ->orderByDesc('total_revenue')
            ->limit($limit)
            ->get();

        // Sales by region
        $salesByRegion = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->join('clients', 'clients.id', '=', 'shipments.client_id')
            ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
            ->select(
                'clients.region',
                DB::raw('SUM(shipment_items.total) as total_revenue'),
                DB::raw('COUNT(DISTINCT shipments.id) as shipment_count'),
                DB::raw('SUM(shipment_items.quantity) as total_quantity')
            )
            ->groupBy('clients.region')
            ->orderByDesc('total_revenue')
            ->get();

        // Client order frequency
        $clientFrequency = DB::table('orders')
            ->join('clients', 'clients.id', '=', 'orders.client_id')
            ->whereBetween('orders.order_date', [$from, $to])
            ->select(
                'clients.id',
                'clients.contact_name',
                'clients.shop_name',
                DB::raw('COUNT(orders.id) as order_count')
            )
            ->groupBy('clients.id', 'clients.contact_name', 'clients.shop_name')
            ->orderByDesc('order_count')
            ->limit($limit)
            ->get();

        $data = [
            'top_clients' => $topClients,
            'sales_by_region' => $salesByRegion,
            'client_frequency' => $clientFrequency,
            'date_from' => $from,
            'date_to' => $to,
        ];

        return response()->json(['data' => $data]);
    }

    /**
     * Get sales analytics data.
     */
    private function getSalesAnalytics(string $from, string $to): array
    {
        // Total revenue and quantity
        $salesSummary = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
            ->selectRaw('
                SUM(shipment_items.total) as total_revenue,
                SUM(shipment_items.quantity) as total_quantity,
                COUNT(DISTINCT shipments.id) as shipment_count
            ')
            ->first();

        // Daily sales trend
        $dailySales = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
            ->select(
                DB::raw('DATE(shipments.shipment_datetime) as date'),
                DB::raw('SUM(shipment_items.total) as revenue'),
                DB::raw('SUM(shipment_items.quantity) as quantity')
            )
            ->groupBy(DB::raw('DATE(shipments.shipment_datetime)'))
            ->orderBy('date')
            ->get();

        // Average order value
        $avgOrderValue = $salesSummary->shipment_count > 0
            ? $salesSummary->total_revenue / $salesSummary->shipment_count
            : 0;

        return [
            'total_revenue' => (float) ($salesSummary->total_revenue ?? 0),
            'total_quantity' => (int) ($salesSummary->total_quantity ?? 0),
            'shipment_count' => (int) ($salesSummary->shipment_count ?? 0),
            'average_order_value' => (float) $avgOrderValue,
            'daily_trend' => $dailySales,
        ];
    }

    /**
     * Get production analytics data.
     */
    private function getProductionAnalytics(string $from, string $to): array
    {
        // Production batches summary
        $batchSummary = DB::table('production_batches')
            ->whereBetween(DB::raw('DATE(created_at)'), [$from, $to])
            ->selectRaw('
                COUNT(id) as total_batches,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as completed_batches,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as in_progress_batches,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as planned_batches,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as cancelled_batches
            ', ['completed', 'in_progress', 'planned', 'cancelled'])
            ->first();

        // Production quantity (from warehouse IN documents)
        $productionQuantity = DB::table('warehouse_document_items')
            ->join('warehouse_documents', 'warehouse_documents.id', '=', 'warehouse_document_items.warehouse_document_id')
            ->where('warehouse_documents.type', WarehouseDocument::TYPE_IN)
            ->whereBetween(DB::raw('DATE(warehouse_documents.document_date)'), [$from, $to])
            ->sum('warehouse_document_items.quantity');

        // Daily production trend
        $dailyProduction = DB::table('warehouse_document_items')
            ->join('warehouse_documents', 'warehouse_documents.id', '=', 'warehouse_document_items.warehouse_document_id')
            ->where('warehouse_documents.type', WarehouseDocument::TYPE_IN)
            ->whereBetween(DB::raw('DATE(warehouse_documents.document_date)'), [$from, $to])
            ->select(
                DB::raw('DATE(warehouse_documents.document_date) as date'),
                DB::raw('SUM(warehouse_document_items.quantity) as quantity')
            )
            ->groupBy(DB::raw('DATE(warehouse_documents.document_date)'))
            ->orderBy('date')
            ->get();

        // Defects analysis
        $defectsCount = DB::table('defect_document_items')
            ->join('defect_documents', 'defect_documents.id', '=', 'defect_document_items.defect_document_id')
            ->whereBetween(DB::raw('DATE(defect_documents.datetime)'), [$from, $to])
            ->sum('defect_document_items.quantity');

        // Machine utilization
        $machineStats = DB::table('production_batches')
            ->join('machines', 'machines.id', '=', 'production_batches.machine_id')
            ->whereBetween(DB::raw('DATE(production_batches.created_at)'), [$from, $to])
            ->select(
                'machines.name as machine_name',
                DB::raw('COUNT(production_batches.id) as batch_count'),
                DB::raw('SUM(CASE WHEN production_batches.status = ? THEN 1 ELSE 0 END) as completed_count', ['completed'])
            )
            ->groupBy('machines.id', 'machines.name')
            ->get();

        $completionRate = $batchSummary->total_batches > 0
            ? ($batchSummary->completed_batches / $batchSummary->total_batches) * 100
            : 0;

        return [
            'total_batches' => (int) $batchSummary->total_batches,
            'completed_batches' => (int) $batchSummary->completed_batches,
            'in_progress_batches' => (int) $batchSummary->in_progress_batches,
            'planned_batches' => (int) $batchSummary->planned_batches,
            'cancelled_batches' => (int) $batchSummary->cancelled_batches,
            'completion_rate' => round($completionRate, 2),
            'production_quantity' => (int) $productionQuantity,
            'defects_quantity' => (int) $defectsCount,
            'daily_trend' => $dailyProduction,
            'machine_stats' => $machineStats,
        ];
    }

    /**
     * Get warehouse analytics data.
     */
    private function getWarehouseAnalytics(string $from, string $to): array
    {
        // Current stock
        $currentStock = DB::table('stock_movements')
            ->selectRaw('
                COALESCE(SUM(CASE WHEN movement_type = ? THEN quantity ELSE -quantity END), 0) as total_stock
            ', [StockMovement::TYPE_IN])
            ->value('total_stock') ?? 0;

        // Stock movements in period
        $movementsSummary = DB::table('stock_movements')
            ->whereBetween(DB::raw('DATE(created_at)'), [$from, $to])
            ->selectRaw('
                SUM(CASE WHEN movement_type = ? THEN quantity ELSE 0 END) as stock_in,
                SUM(CASE WHEN movement_type = ? THEN quantity ELSE 0 END) as stock_out
            ', [StockMovement::TYPE_IN, StockMovement::TYPE_OUT])
            ->first();

        // Daily stock movements
        $dailyMovements = DB::table('stock_movements')
            ->whereBetween(DB::raw('DATE(created_at)'), [$from, $to])
            ->select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('SUM(CASE WHEN movement_type = ? THEN quantity ELSE 0 END) as stock_in', [StockMovement::TYPE_IN]),
                DB::raw('SUM(CASE WHEN movement_type = ? THEN quantity ELSE 0 END) as stock_out', [StockMovement::TYPE_OUT])
            )
            ->groupBy(DB::raw('DATE(created_at)'))
            ->orderBy('date')
            ->get();

        // Stock by product variant (top 20)
        $stockByVariant = DB::table('stock_movements')
            ->join('product_variants', 'product_variants.id', '=', 'stock_movements.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->join('product_sizes', 'product_sizes.id', '=', 'product_colors.size_id')
            ->select(
                'products.name as product_name',
                'product_sizes.name as size_name',
                'product_variants.sku_code',
                DB::raw('SUM(CASE WHEN stock_movements.movement_type = ? THEN quantity ELSE -quantity END) as stock', [StockMovement::TYPE_IN])
            )
            ->groupBy('product_variants.id', 'products.name', 'product_sizes.name', 'product_variants.sku_code')
            ->havingRaw('stock > 0')
            ->orderByDesc('stock')
            ->limit(20)
            ->get();

        return [
            'current_stock' => (int) $currentStock,
            'stock_in' => (int) ($movementsSummary->stock_in ?? 0),
            'stock_out' => (int) ($movementsSummary->stock_out ?? 0),
            'daily_movements' => $dailyMovements,
            'top_stock_items' => $stockByVariant,
        ];
    }

    /**
     * Get financial analytics data.
     */
    private function getFinancialAnalytics(string $from, string $to): array
    {
        // Total revenue from shipments
        $totalRevenue = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
            ->sum('shipment_items.total');

        // Total payments received
        $totalPayments = DB::table('payments')
            ->whereBetween(DB::raw('DATE(created_at)'), [$from, $to])
            ->sum('amount');

        // Outstanding debts (total shipments - total payments) for all clients
        $totalShipments = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->sum('shipment_items.total');

        $totalAllPayments = DB::table('payments')->sum('amount');
        $outstandingDebt = $totalShipments - $totalAllPayments;

        // Top debtors
        $topDebtors = DB::table('clients')
            ->leftJoin('shipments', 'shipments.client_id', '=', 'clients.id')
            ->leftJoin('shipment_items', 'shipment_items.shipment_id', '=', 'shipments.id')
            ->leftJoin('payments', 'payments.client_id', '=', 'clients.id')
            ->select(
                'clients.id',
                'clients.contact_name',
                'clients.shop_name',
                'clients.region',
                DB::raw('COALESCE(SUM(shipment_items.total), 0) as total_sales'),
                DB::raw('COALESCE(SUM(payments.amount), 0) as total_payments'),
                DB::raw('COALESCE(SUM(shipment_items.total), 0) - COALESCE(SUM(payments.amount), 0) as debt')
            )
            ->groupBy('clients.id', 'clients.contact_name', 'clients.shop_name', 'clients.region')
            ->havingRaw('debt > 0')
            ->orderByDesc('debt')
            ->limit(10)
            ->get();

        // Daily payment trend
        $dailyPayments = DB::table('payments')
            ->whereBetween(DB::raw('DATE(created_at)'), [$from, $to])
            ->select(
                DB::raw('DATE(created_at) as date'),
                DB::raw('SUM(amount) as amount'),
                DB::raw('COUNT(id) as count')
            )
            ->groupBy(DB::raw('DATE(created_at)'))
            ->orderBy('date')
            ->get();

        return [
            'total_revenue' => (float) ($totalRevenue ?? 0),
            'total_payments' => (float) ($totalPayments ?? 0),
            'outstanding_debt' => (float) $outstandingDebt,
            'revenue_minus_payments' => (float) (($totalRevenue ?? 0) - ($totalPayments ?? 0)),
            'top_debtors' => $topDebtors,
            'daily_payments' => $dailyPayments,
        ];
    }

    /**
     * Get order analytics data.
     */
    private function getOrderAnalytics(string $from, string $to): array
    {
        // Order status distribution
        $statusDistribution = DB::table('orders')
            ->whereBetween('order_date', [$from, $to])
            ->select(
                'status',
                DB::raw('COUNT(id) as count')
            )
            ->groupBy('status')
            ->get();

        // Total orders
        $totalOrders = DB::table('orders')
            ->whereBetween('order_date', [$from, $to])
            ->count();

        // Daily order trend
        $dailyOrders = DB::table('orders')
            ->whereBetween('order_date', [$from, $to])
            ->select(
                'order_date as date',
                DB::raw('COUNT(id) as count')
            )
            ->groupBy('order_date')
            ->orderBy('date')
            ->get();

        // Average fulfillment time (from order date to shipped status)
        $avgFulfillmentTime = DB::table('orders')
            ->join('shipments', 'shipments.order_id', '=', 'orders.id')
            ->whereBetween('orders.order_date', [$from, $to])
            ->selectRaw('AVG(DATEDIFF(DATE(shipments.shipment_datetime), orders.order_date)) as avg_days')
            ->value('avg_days');

        return [
            'total_orders' => $totalOrders,
            'status_distribution' => $statusDistribution,
            'daily_trend' => $dailyOrders,
            'avg_fulfillment_days' => $avgFulfillmentTime ? round($avgFulfillmentTime, 1) : null,
        ];
    }
}
