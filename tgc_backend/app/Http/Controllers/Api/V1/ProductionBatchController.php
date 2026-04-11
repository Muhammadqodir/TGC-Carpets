<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Production\StoreProductionBatchRequest;
use App\Http\Requests\Production\UpdateProductionBatchRequest;
use App\Http\Requests\Production\UpdateProductionBatchItemRequest;
use App\Http\Resources\ProductionBatchResource;
use App\Http\Resources\ProductionBatchItemResource;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Services\ProductionBatchService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class ProductionBatchController extends Controller
{
    public function __construct(private readonly ProductionBatchService $service) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $batches = ProductionBatch::select('production_batches.*')
            ->addSelect(DB::raw('(
                SELECT COALESCE(SUM(pbi.planned_quantity * ps.length * ps.width), 0) / 10000.0
                FROM production_batch_items pbi
                INNER JOIN product_variants pv ON pv.id = pbi.product_variant_id
                INNER JOIN product_sizes ps ON ps.id = pv.product_size_id
                WHERE pbi.production_batch_id = production_batches.id
            ) AS total_sqm'))
            ->with(['machine', 'creator'])
            ->withCount('items')
            ->withSum('items', 'planned_quantity')
            ->when($request->filled('status'),     fn ($q) => $q->where('status', $request->status))
            ->when($request->filled('type'),       fn ($q) => $q->where('type', $request->type))
            ->when($request->filled('machine_id'), fn ($q) => $q->where('machine_id', $request->machine_id))
            ->when($request->filled('date_from'),  fn ($q) => $q->whereDate('planned_datetime', '>=', $request->date_from))
            ->when($request->filled('date_to'),    fn ($q) => $q->whereDate('planned_datetime', '<=', $request->date_to))
            ->latest('planned_datetime')
            ->paginate($request->integer('per_page', 20));

        return ProductionBatchResource::collection($batches);
    }

    public function store(StoreProductionBatchRequest $request): JsonResponse
    {
        $batch = $this->service->create($request->validated(), $request->user()->id);

        return response()->json(['data' => new ProductionBatchResource($batch)], 201);
    }

    public function show(ProductionBatch $productionBatch): JsonResponse
    {
        $productionBatch->load([
            'machine',
            'creator',
            'responsibleEmployee',
            'items.variant.productColor.product.productType',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.color',
            'items.variant.productSize',
            'items.sourceOrderItem.order.client',
        ]);

        return response()->json(['data' => new ProductionBatchResource($productionBatch)]);
    }

    public function update(UpdateProductionBatchRequest $request, ProductionBatch $productionBatch): JsonResponse
    {
        $updated = $this->service->update($productionBatch, $request->validated());

        return response()->json(['data' => new ProductionBatchResource($updated)]);
    }

    public function destroy(ProductionBatch $productionBatch): JsonResponse
    {
        $this->service->delete($productionBatch);

        return response()->json(['message' => 'Production batch deleted.']);
    }

    /**
     * POST /production-batches/{productionBatch}/start
     */
    public function start(Request $request, ProductionBatch $productionBatch): JsonResponse
    {
        if ($productionBatch->status !== ProductionBatch::STATUS_PLANNED) {
            return response()->json(['message' => 'Batch can only be started from planned status.'], 422);
        }

        $validated = $request->validate([
            'responsible_employee_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        $updated = $this->service->start(
            $productionBatch,
            $validated['responsible_employee_id'],
        );

        return response()->json(['data' => new ProductionBatchResource($updated)]);
    }

    /**
     * POST /production-batches/{productionBatch}/complete
     */
    public function complete(ProductionBatch $productionBatch): JsonResponse
    {
        if ($productionBatch->status !== ProductionBatch::STATUS_IN_PROGRESS) {
            return response()->json(['message' => 'Batch can only be completed from in_progress status.'], 422);
        }

        $updated = $this->service->complete($productionBatch);

        return response()->json(['data' => new ProductionBatchResource($updated)]);
    }

    /**
     * POST /production-batches/{productionBatch}/cancel
     */
    public function cancel(ProductionBatch $productionBatch): JsonResponse
    {
        if ($productionBatch->status === ProductionBatch::STATUS_COMPLETED) {
            return response()->json(['message' => 'Completed batches cannot be cancelled.'], 422);
        }

        $updated = $this->service->cancel($productionBatch);

        return response()->json(['data' => new ProductionBatchResource($updated)]);
    }

    /**
     * PATCH /production-batches/{productionBatch}/items/{item}
     * Update produced/defect quantities during production.
     */
    public function updateItem(
        UpdateProductionBatchItemRequest $request,
        ProductionBatch $productionBatch,
        ProductionBatchItem $item,
    ): JsonResponse {
        if ($item->production_batch_id !== $productionBatch->id) {
            return response()->json(['message' => 'Item does not belong to this batch.'], 404);
        }

        $updated = $this->service->updateItem($item, $request->validated());

        return response()->json(['data' => new ProductionBatchItemResource($updated)]);
    }

    /**
     * GET /production-batches/order-items-available
     * Returns order items available for production (with remaining quantities).
     */
    public function orderItemsAvailable(Request $request): JsonResponse
    {
        $orderItems = OrderItem::with([
                'order.client',
                'variant.productColor.product.productType',
                'variant.productColor.product.productQuality',
                'variant.productColor.color',
                'variant.productSize',
            ])
            ->whereHas('order', fn ($q) => $q->whereIn('status', ['pending', 'planned', 'on_production']))
            ->get()
            ->map(function (OrderItem $oi) {
                // Calculate already planned quantity across all non-cancelled batches
                $alreadyPlanned = ProductionBatchItem::where('source_order_item_id', $oi->id)
                    ->whereHas('productionBatch', fn ($q) => $q->where('status', '!=', 'cancelled'))
                    ->sum('planned_quantity');

                $remaining = max(0, $oi->quantity - $alreadyPlanned);

                return [
                    'order_item_id'     => $oi->id,
                    'order_id'          => $oi->order_id,
                    'order_number'      => $oi->order->id,
                    'client_shop_name'  => $oi->order->client?->shop_name,
                    'ordered_quantity'   => $oi->quantity,
                    'planned_quantity'   => (int) $alreadyPlanned,
                    'remaining_quantity' => $remaining,
                    'variant'           => [
                        'id'            => $oi->variant->id,
                        'barcode_value' => $oi->variant->barcode_value,
                        'sku_code'      => $oi->variant->sku_code,
                        'product_color' => $oi->variant->productColor ? [
                            'id'        => $oi->variant->productColor->id,
                            'image_url' => $oi->variant->productColor->image
                                ? \Illuminate\Support\Facades\Storage::disk('public')->url($oi->variant->productColor->image)
                                : null,
                            'color'   => $oi->variant->productColor->color
                                ? ['id' => $oi->variant->productColor->color->id, 'name' => $oi->variant->productColor->color->name]
                                : null,
                            'product' => $oi->variant->productColor->product
                                ? [
                                    'id'           => $oi->variant->productColor->product->id,
                                    'name'         => $oi->variant->productColor->product->name,
                                    'product_type' => $oi->variant->productColor->product->productType
                                        ? ['id' => $oi->variant->productColor->product->productType->id, 'type' => $oi->variant->productColor->product->productType->type]
                                        : null,
                                    'quality_name' => $oi->variant->productColor->product->productQuality?->quality_name,
                                ]
                                : null,
                        ] : null,
                        'product_size' => $oi->variant->productSize
                            ? ['id' => $oi->variant->productSize->id, 'length' => $oi->variant->productSize->length, 'width' => $oi->variant->productSize->width]
                            : null,
                    ],
                ];
            })
            ->filter(fn ($item) => $item['remaining_quantity'] > 0)
            ->values();

        return response()->json(['data' => $orderItems]);
    }
}
