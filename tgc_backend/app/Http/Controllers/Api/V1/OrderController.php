<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Order\StoreOrderRequest;
use App\Http\Requests\Order\UpdateOrderRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class OrderController extends Controller
{
    public function __construct(private readonly OrderService $service) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $orders = Order::with(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.productionBatchItems.productionBatch', 'items.shipmentItems'])
            ->when($request->filled('status'),    fn ($q) => $q->where('status', $request->status))
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->client_id))
            ->when($request->filled('user_id'),   fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('date_from'), fn ($q) => $q->whereDate('order_date', '>=', $request->date_from))
            ->when($request->filled('date_to'),   fn ($q) => $q->whereDate('order_date', '<=', $request->date_to))
            ->when($request->boolean('for_production'), function ($q) {
                // Return orders that are not yet fully in production:
                // status is pending, planned, or on_production AND at least one item
                // still has quantity not covered by non-cancelled production batches.
                $q->whereIn('status', [Order::STATUS_PENDING, Order::STATUS_PLANNED, Order::STATUS_ON_PRODUCTION])
                  ->whereHas('items', function ($iq) {
                      $iq->whereRaw(
                          'quantity > COALESCE((
                              SELECT SUM(pbi.planned_quantity)
                              FROM production_batch_items pbi
                              INNER JOIN production_batches pb ON pb.id = pbi.production_batch_id
                              WHERE pbi.source_order_item_id = order_items.id
                                AND pb.status != ?
                          ), 0)',
                          [\App\Models\ProductionBatch::STATUS_CANCELLED]
                      );
                  });
            })
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return OrderResource::collection($orders);
    }

    public function store(StoreOrderRequest $request): JsonResponse
    {
        $order = $this->service->create($request->validated(), $request->user()->id);

        $statusCode = $order->wasRecentlyCreated ? 201 : 200;

        return response()->json(['data' => new OrderResource($order)], $statusCode);
    }

    public function show(Order $order): JsonResponse
    {
        $order->load(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.productionBatchItems.productionBatch', 'items.shipmentItems']);

        return response()->json(['data' => new OrderResource($order)]);
    }

    public function update(UpdateOrderRequest $request, Order $order): JsonResponse
    {
        $updated = $this->service->update($order, $request->validated());

        return response()->json(['data' => new OrderResource($updated)]);
    }

    public function destroy(Order $order): JsonResponse
    {
        $this->service->delete($order);

        return response()->json(['message' => 'Order deleted.']);
    }
}
