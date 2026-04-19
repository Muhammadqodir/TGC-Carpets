<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\StockMovementResource;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class StockController extends Controller
{
    /**
     * GET /api/v1/stock
     *
     * Returns current calculated stock level per product.
     */
    public function index(Request $request): JsonResponse
    {
        $stockIn = DB::table('stock_movements')
            ->join('product_variants', 'product_variants.id', '=', 'stock_movements.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->selectRaw('COALESCE(SUM(quantity), 0)')
            ->whereIn('movement_type', [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN])
            ->whereColumn('product_colors.product_id', 'products.id');

        $stockOut = DB::table('stock_movements')
            ->join('product_variants', 'product_variants.id', '=', 'stock_movements.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->selectRaw('COALESCE(SUM(quantity), 0)')
            ->where('movement_type', WarehouseDocument::TYPE_OUT)
            ->whereColumn('product_colors.product_id', 'products.id');

        $query = Product::withTrashed(false)
            ->with(['productQuality', 'productColors.color'])
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->status))
            ->when($request->filled('name'),   fn ($q) => $q->where('name', 'like', '%'.$request->name.'%'))
            ->select('id', 'uuid', 'name', 'unit', 'status', 'product_quality_id')
            ->selectSub($stockIn, 'stock_in')
            ->selectSub($stockOut, 'stock_out')
            ->latest()
            ->paginate($request->integer('per_page', 50));

        $query->through(function ($product) {
            $product->current_stock = (int) ($product->stock_in - $product->stock_out);

            return $product;
        });

        return response()->json([
            'data' => $query->map(fn ($p) => [
                'id'            => $p->id,
                'uuid'          => $p->uuid,
                'name'          => $p->name,
                'unit'          => $p->unit,
                'status'        => $p->status,
                'quality'       => $p->productQuality?->name,
                'colors'        => $p->productColors->map(fn ($pc) => $pc->color->name)->unique()->values(),
                'stock_in'      => (int) $p->stock_in,
                'stock_out'     => (int) $p->stock_out,
                'current_stock' => $p->current_stock,
            ]),
            'meta' => [
                'current_page' => $query->currentPage(),
                'last_page'    => $query->lastPage(),
                'per_page'     => $query->perPage(),
                'total'        => $query->total(),
            ],
        ]);
    }

    /**
     * GET /api/v1/stock/variants
     *
     * Per-variant stock view — only variants with quantity_warehouse > 0.
     *
     * quantity_warehouse : net stock (in + return − out) from stock_movements
     * quantity_reserved  : goods produced for active (non-cancelled, non-done) order
     *                      items that arrived in the warehouse, minus what has already
     *                      been shipped against those same order items.
     *
     * Filters: product_type_id, product_quality_id, product_size_id
     */
    public function variants(Request $request): JsonResponse
    {
        // Correlated sub-query: net warehouse stock per variant
        $qtyWarehouse = DB::table('stock_movements as sm')
            ->selectRaw(
                'COALESCE(SUM(CASE WHEN sm.movement_type IN (?, ?) THEN sm.quantity ELSE -sm.quantity END), 0)',
                [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN]
            )
            ->whereColumn('sm.product_variant_id', 'product_variants.id');

        // Correlated sub-query: qty received into warehouse for active-order batch items.
        // Excludes 'canceled' and 'shipped' orders only — 'done' means all items are
        // physically in the warehouse awaiting shipment, so they must be counted here.
        $qtyReceivedForActiveOrders = DB::table('production_batch_items as pbi')
            ->join('order_items as oi', 'oi.id', '=', 'pbi.source_order_item_id')
            ->join('orders as o', 'o.id', '=', 'oi.order_id')
            ->selectRaw('COALESCE(SUM(pbi.warehouse_received_quantity), 0)')
            ->whereColumn('pbi.product_variant_id', 'product_variants.id')
            ->where('pbi.source_type', 'order_item')
            ->whereNotIn('o.status', ['canceled', 'shipped']);

        // Correlated sub-query: qty already shipped against those same active orders
        $qtyShippedForActiveOrders = DB::table('shipment_items as si')
            ->join('order_items as oi', 'oi.id', '=', 'si.order_item_id')
            ->join('orders as o', 'o.id', '=', 'oi.order_id')
            ->selectRaw('COALESCE(SUM(si.quantity), 0)')
            ->whereColumn('si.product_variant_id', 'product_variants.id')
            ->whereNotIn('o.status', ['canceled', 'shipped']);

        $results = DB::table('product_variants')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->leftJoin('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->whereNull('products.deleted_at')
            ->select([
                'product_variants.id',
                'products.name as product_name',
                'colors.name as color_name',
                'product_colors.image as color_image',
                'product_qualities.quality_name',
                'product_types.type as type_name',
                'product_variants.length',
                'product_variants.width',
            ])
            ->selectSub($qtyWarehouse, 'quantity_warehouse')
            ->selectSub($qtyReceivedForActiveOrders, 'qty_received')
            ->selectSub($qtyShippedForActiveOrders, 'qty_shipped')
            ->when(
                $request->filled('product_type_id'),
                fn ($q) => $q->where('products.product_type_id', $request->integer('product_type_id'))
            )
            ->when(
                $request->filled('product_quality_id'),
                fn ($q) => $q->where('products.product_quality_id', $request->integer('product_quality_id'))
            )
            ->when(
                $request->filled('search'),
                fn ($q) => $q->where('products.name', 'like', '%' . $request->string('search') . '%')
            )
            ->having('quantity_warehouse', '>', 0)
            ->orderByDesc('quantity_warehouse')
            ->paginate(
                $request->integer('per_page', 20),
                ['*'],
                'page',
                $request->integer('page', 1)
            );

        $baseUrl = rtrim(config('app.url'), '/');

        $data = collect($results->items())->map(fn ($row) => [
            'id'                 => $row->id,
            'product_name'       => $row->product_name,
            'color_name'         => $row->color_name,
            'image_url'          => $row->color_image
                ? $baseUrl . '/storage/' . $row->color_image
                : null,
            'quality_name'       => $row->quality_name,
            'type_name'          => $row->type_name,
            'size'               => ($row->length && $row->width)
                ? "{$row->length}x{$row->width}"
                : null,
            'quantity_reserved'  => max(0, (int) $row->qty_received - (int) $row->qty_shipped),
            'quantity_warehouse' => (int) $row->quantity_warehouse,
        ]);

        return response()->json([
            'data' => $data,
            'meta' => [
                'current_page' => $results->currentPage(),
                'last_page'    => $results->lastPage(),
                'per_page'     => $results->perPage(),
                'total'        => $results->total(),
            ],
        ]);
    }

    /**
     * GET /api/v1/stock/movements
     *
     * Paginated, filterable stock movement history.
     */
    public function movements(Request $request): AnonymousResourceCollection
    {
        $movements = StockMovement::with(['variant.productColor.product', 'variant.productColor.color', 'user'])
            ->when($request->filled('product_id'),    fn ($q) => $q->whereHas('variant.productColor', fn ($q2) => $q2->where('product_id', $request->product_id)))
            ->when($request->filled('movement_type'), fn ($q) => $q->where('movement_type', $request->movement_type))
            ->when($request->filled('warehouse_document_item_id'), fn ($q) => $q->where('warehouse_document_item_id', $request->warehouse_document_item_id))
            ->when($request->filled('user_id'),       fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('date_from'),     fn ($q) => $q->whereDate('movement_date', '>=', $request->date_from))
            ->when($request->filled('date_to'),       fn ($q) => $q->whereDate('movement_date', '<=', $request->date_to))
            ->latest('movement_date')
            ->paginate($request->integer('per_page', 50));

        return StockMovementResource::collection($movements);
    }
}

