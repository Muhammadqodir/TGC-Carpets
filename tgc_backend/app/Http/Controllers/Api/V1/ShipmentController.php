<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Shipment\StoreShipmentRequest;
use App\Http\Requests\Shipment\UpdateShipmentPricesRequest;
use App\Http\Resources\OrderResource;
use App\Http\Resources\ShipmentResource;
use App\Models\Order;
use App\Models\Shipment;
use App\Services\ShipmentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ShipmentController extends Controller
{
    public function __construct(private readonly ShipmentService $service) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $shipments = Shipment::with([
                'client',
                'user',
                'items.variant.productColor.product',
                'items.variant.productColor.color',
                'items.variant.productSize',
                'items.variant.productEdge',
                'items.orderItem.order',
            ])
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->integer('client_id')))
            ->when($request->filled('date_from'),  fn ($q) => $q->whereDate('shipment_datetime', '>=', $request->date_from))
            ->when($request->filled('date_to'),    fn ($q) => $q->whereDate('shipment_datetime', '<=', $request->date_to))
            ->latest('shipment_datetime')
            ->paginate($this->perPage($request));

        return ShipmentResource::collection($shipments);
    }

    public function store(StoreShipmentRequest $request): JsonResponse
    {
        $shipment = $this->service->create($request->validated(), $request->user()->id);

        return response()->json(['data' => new ShipmentResource($shipment)], 201);
    }

    /**
     * POST /shipments/{shipment}/cancel
     *
     * Admin only (role middleware on the route): this puts stock back and
     * wipes the client's debt for the shipment. See ShipmentService::cancel()
     * for everything it reverses.
     */
    public function cancel(Request $request, Shipment $shipment): JsonResponse
    {
        $validated = $request->validate([
            'reason' => ['nullable', 'string', 'max:1000'],
        ]);

        $canceled = $this->service->cancel(
            $shipment,
            $request->user()->id,
            $validated['reason'] ?? null,
        );

        $canceled->load([
            'items.variant.productColor.product',
            'items.variant.productColor.color',
            'items.variant.productSize',
            'items.variant.productEdge',
            'items.orderItem.order',
        ]);

        return response()->json(['data' => new ShipmentResource($canceled)]);
    }

    /**
     * POST /shipments/{shipment}/prices
     *
     * Fills in the prices of an already-created shipment and regenerates its
     * documents — the step that turns a loaded lorry into an invoice.
     *
     * Admin or pricing_manager (role middleware on the route): this is what
     * moves a client's debt, so it is deliberately not open to the warehouse
     * roles that create the shipment in the first place.
     */
    public function updatePrices(UpdateShipmentPricesRequest $request, Shipment $shipment): JsonResponse
    {
        $updated = $this->service->updatePrices(
            $shipment,
            $request->validated()['items'],
            $request->user()->id,
        );

        return response()->json(['data' => new ShipmentResource($updated)]);
    }

    public function show(Shipment $shipment): JsonResponse
    {
        $shipment->load([
            'client',
            'user',
            'items.variant.productColor.product',
            'items.variant.productColor.color',
            'items.variant.productSize',
            'items.variant.productEdge',
            'items.orderItem.order',
        ]);

        return response()->json(['data' => new ShipmentResource($shipment)]);
    }

    /**
     * Return orders with status on_production or done, with their items
     * and current warehouse stock per variant. Used to pre-fill shipment form.
     * Also includes pending/planned orders that have warehouse-received items
     * (handles cancelled batches with received production).
     */
    public function ordersForShipment(Request $request): AnonymousResourceCollection
    {
        $orders = Order::with([
                'client',
                'items.variant.productColor.product.productType',
                'items.variant.productColor.product.productQuality',
                'items.variant.productColor.color',
                'items.variant.productSize',
                'items.variant.productEdge',
                'items.shipmentItems',
                // Note: productionBatchItems loaded without nested productionBatch to avoid circular reference
                'items.productionBatchItems',
            ])
            ->where(function ($q) {
                // Include on_production and done orders
                $q->whereIn('status', [Order::STATUS_ON_PRODUCTION, Order::STATUS_DONE])
                  // Also include pending/planned orders that have warehouse-received items
                  // (e.g., when batch was cancelled but items were produced and received)
                  ->orWhere(function ($subQ) {
                      $subQ->whereIn('status', [Order::STATUS_PENDING, Order::STATUS_PLANNED])
                           ->whereHas('items.productionBatchItems', fn ($pq) =>
                               $pq->where('warehouse_received_quantity', '>', 0)
                           );
                  });
            })
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->integer('client_id')))
            ->latest('order_date')
            ->paginate($this->perPage($request));

        return OrderResource::collection($orders);
    }

    /**
     * Return the last known price for a product variant + client combination.
     * Used to pre-fill the price column in the shipment form.
     */
    public function lastPrice(Request $request): JsonResponse
    {
        $request->validate([
            'variant_id' => ['required', 'integer', 'exists:product_variants,id'],
            'client_id'  => ['required', 'integer', 'exists:clients,id'],
        ]);

        $price = $this->service->getLastPrice(
            $request->integer('variant_id'),
            $request->integer('client_id'),
        );

        return response()->json(['data' => ['price' => $price]]);
    }
}
