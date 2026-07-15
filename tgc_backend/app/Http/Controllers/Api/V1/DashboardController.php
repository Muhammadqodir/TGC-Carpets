<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\StockMovement;
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
                'COALESCE(SUM(CASE WHEN movement_type = ? THEN quantity ELSE -quantity END), 0) as net',
                [StockMovement::TYPE_IN]
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

        // TODO(instructions/phase-0/01): shipments_amount was removed here because
        // shipment_items.total no longer exists (dropped in
        // 2026_04_16_000001_drop_total_from_shipment_items_table). Reinstate it in
        // phase-1/01 using the shared line-total formula instead of a fifth copy.
        //
        // TODO(instructions/phase-0/01): warehouse_stock (below) ignores $from/$to —
        // it nets ALL movements ever, not just the period. LOGIC-6, out of scope here.
        //
        // TODO(instructions/phase-0/01): production_quantity counts warehouse 'in'
        // document items, including supplier deliveries and not excluding cancelled
        // batches, so it can never reconcile with Production Analytics. LOGIC-6.

        return response()->json([
            'data' => [
                'production_quantity'  => (int) $productionQuantity,
                'warehouse_stock'      => (int) $warehouseStock,
                'shipments_quantity'   => (int) $shipmentsQuantity,
                'date_from'            => $from,
                'date_to'              => $to,
            ],
        ]);
    }
}
