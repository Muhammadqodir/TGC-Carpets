<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Shipment\StoreShipmentRequest;
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
            ])
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->integer('client_id')))
            ->when($request->filled('date_from'),  fn ($q) => $q->whereDate('shipment_datetime', '>=', $request->date_from))
            ->when($request->filled('date_to'),    fn ($q) => $q->whereDate('shipment_datetime', '<=', $request->date_to))
            ->latest('shipment_datetime')
            ->paginate($request->integer('per_page', 20));

        return ShipmentResource::collection($shipments);
    }

    public function store(StoreShipmentRequest $request): JsonResponse
    {
        $shipment = $this->service->create($request->validated(), $request->user()->id);

        return response()->json(['data' => new ShipmentResource($shipment)], 201);
    }

    public function show(Shipment $shipment): JsonResponse
    {
        $shipment->load([
            'client',
            'user',
            'items.variant.productColor.product',
            'items.variant.productColor.color',
            'items.variant.productSize',
        ]);

        return response()->json(['data' => new ShipmentResource($shipment)]);
    }

    /**
     * Return orders with status on_production or done, with their items
     * and current warehouse stock per variant. Used to pre-fill shipment form.
     */
    public function ordersForShipment(Request $request): AnonymousResourceCollection
    {
        $orders = Order::with([
                'client',
                'items.variant.productColor.product.productType',
                'items.variant.productColor.product.productQuality',
                'items.variant.productColor.color',
                'items.variant.productSize',
                'items.shipmentItems',
                'items.productionBatchItems.productionBatch',
            ])
            ->whereIn('status', [Order::STATUS_ON_PRODUCTION, Order::STATUS_DONE])
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->integer('client_id')))
            ->latest('order_date')
            ->paginate($request->integer('per_page', 50));

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
