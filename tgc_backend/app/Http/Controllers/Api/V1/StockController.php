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

class StockController extends Controller
{
    /**
     * GET /api/v1/stock
     *
     * Returns current calculated stock level per product.
     *
     * Stock is computed live from stock_movements using two aggregated subqueries.
     * This approach removes the risk of a cached column drifting out of sync.
     * For high-traffic production workloads, consider materialising these sums
     * into a product_stocks table and invalidating on movement writes.
     */
    public function index(Request $request): JsonResponse
    {
        $query = Product::withTrashed(false)
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->status))
            ->when($request->filled('name'),   fn ($q) => $q->where('name', 'like', '%'.$request->name.'%'))
            ->when($request->filled('color'),  fn ($q) => $q->where('color', $request->color))
            ->select('id', 'uuid', 'name', 'sku_code', 'unit', 'status', 'color', 'quality')
            ->withSum(
                ['stockMovements as stock_in' => fn ($q) => $q->whereIn('movement_type', [
                    WarehouseDocument::TYPE_IN,
                    WarehouseDocument::TYPE_RETURN,
                ])],
                'quantity'
            )
            ->withSum(
                ['stockMovements as stock_out' => fn ($q) => $q->where('movement_type', WarehouseDocument::TYPE_OUT)],
                'quantity'
            )
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
                'sku_code'      => $p->sku_code,
                'unit'          => $p->unit,
                'status'        => $p->status,
                'color'         => $p->color,
                'quality'       => $p->quality,
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
     * GET /api/v1/stock/movements
     *
     * Paginated, filterable stock movement history.
     */
    public function movements(Request $request): AnonymousResourceCollection
    {
        $movements = StockMovement::with(['product', 'productSize', 'client', 'user'])
            ->when($request->filled('product_id'),    fn ($q) => $q->where('product_id', $request->product_id))
            ->when($request->filled('movement_type'), fn ($q) => $q->where('movement_type', $request->movement_type))
            ->when($request->filled('client_id'),     fn ($q) => $q->where('client_id', $request->client_id))
            ->when($request->filled('user_id'),       fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('date_from'),     fn ($q) => $q->whereDate('movement_date', '>=', $request->date_from))
            ->when($request->filled('date_to'),       fn ($q) => $q->whereDate('movement_date', '<=', $request->date_to))
            ->latest('movement_date')
            ->paginate($request->integer('per_page', 50));

        return StockMovementResource::collection($movements);
    }
}
