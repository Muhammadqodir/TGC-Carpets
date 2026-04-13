<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\WarehouseDocument;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    /**
     * GET /api/v1/dashboard/stats?from=YYYY-MM-DD&to=YYYY-MM-DD
     *
     * Returns aggregated business statistics for the given date range.
     * Defaults to the current calendar month.
     */
    public function stats(Request $request): JsonResponse
    {
        $from = $request->input('from', now()->startOfMonth()->toDateString());
        $to   = $request->input('to',   now()->endOfMonth()->toDateString());

        // Production: sum of quantities on 'in' warehouse documents in range
        $productionQuantity = DB::table('warehouse_document_items')
            ->join(
                'warehouse_documents',
                'warehouse_documents.id',
                '=',
                'warehouse_document_items.warehouse_document_id'
            )
            ->where('warehouse_documents.type', WarehouseDocument::TYPE_IN)
            ->whereBetween(
                DB::raw('DATE(warehouse_documents.document_date)'),
                [$from, $to]
            )
            ->sum('warehouse_document_items.quantity');

        // Current warehouse stock: net of all stock movements
        $warehouseStock = DB::table('stock_movements')
            ->selectRaw(
                'COALESCE(SUM(CASE WHEN movement_type IN (?, ?) THEN quantity ELSE -quantity END), 0) as net',
                [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN]
            )
            ->value('net') ?? 0;

        // Shipments quantity: total items shipped in range
        $shipmentsQuantity = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->whereBetween(
                DB::raw('DATE(shipments.shipment_datetime)'),
                [$from, $to]
            )
            ->sum('shipment_items.quantity');

        // Shipments revenue: total shipment item amounts in range
        $shipmentsAmount = DB::table('shipment_items')
            ->join('shipments', 'shipments.id', '=', 'shipment_items.shipment_id')
            ->whereBetween(DB::raw('DATE(shipments.shipment_datetime)'), [$from, $to])
            ->sum('shipment_items.total');

        return response()->json([
            'data' => [
                'production_quantity'  => (int) $productionQuantity,
                'warehouse_stock'      => (int) $warehouseStock,
                'shipments_quantity'   => (int) $shipmentsQuantity,
                'shipments_amount'     => (float) $shipmentsAmount,
                'date_from'            => $from,
                'date_to'              => $to,
            ],
        ]);
    }
}
