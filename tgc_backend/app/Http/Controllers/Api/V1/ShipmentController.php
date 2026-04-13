<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ShipmentResource;
use App\Models\Shipment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ShipmentController extends Controller
{
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
}
