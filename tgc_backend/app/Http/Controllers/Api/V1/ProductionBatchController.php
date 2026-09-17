<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Production\StoreProductionBatchRequest;
use App\Http\Requests\Production\UpdateProductionBatchRequest;
use App\Http\Requests\Production\UpdateProductionBatchItemRequest;
use App\Http\Resources\ProductionBatchResource;
use App\Http\Resources\ProductionBatchItemResource;
use App\Models\LabelReprint;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\StockMovement;
use App\Services\ProductionBatchService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

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
            // Exclude batches where every produced item has already been received into the warehouse.
            // Note: produced_quantity is already net good units (excludes defects), so no need to subtract defect_quantity.
            ->when($request->boolean('exclude_warehouse_received'), fn ($q) => $q->whereHas('items', fn ($iq) =>
                $iq->whereRaw('(COALESCE(produced_quantity, 0) - COALESCE(warehouse_received_quantity, 0)) > 0')
            ))
            ->latest('production_batches.id')
            ->paginate($this->perPage($request));

        return ProductionBatchResource::collection($batches);
    }

    public function store(StoreProductionBatchRequest $request): JsonResponse
    {
        $batch = $this->service->create($request->validated(), $request->user()->id);

        return response()->json(['data' => new ProductionBatchResource($batch)], 201);
    }

    public function show(Request $request, ProductionBatch $productionBatch): JsonResponse
    {
        $productionBatch->load(['machine', 'creator', 'responsibleEmployee']);

        $itemsQuery = $productionBatch->items()->with([
            'variant.productColor.product.productType',
            'variant.productColor.product.productQuality',
            'variant.productColor.color',
            'variant.productSize',
            'variant.productEdge',
            'sourceOrderItem.order.client',
        ]);

        // When requested, exclude items already fully received into the warehouse.
        // Note: produced_quantity is already net good units (excludes defects), so no need to subtract defect_quantity.
        if ($request->boolean('exclude_warehouse_received')) {
            $itemsQuery->whereRaw(
                '(COALESCE(produced_quantity, 0) - COALESCE(warehouse_received_quantity, 0)) > 0'
            );
        }

        $productionBatch->setRelation('items', $itemsQuery->get());

        return response()->json(['data' => new ProductionBatchResource($productionBatch)]);
    }

    public function update(UpdateProductionBatchRequest $request, ProductionBatch $productionBatch): JsonResponse
    {
        $updated = $this->service->update($productionBatch, $request->validated());

        return response()->json(['data' => new ProductionBatchResource($updated)]);
    }

    /**
     * A batch may be deleted as long as it is not completed. The service's
     * assertNoRecordedProduction() is the real gate — nothing can be
     * deleted once a label has been printed, a defect logged, or a
     * warehouse receipt applied to any of its items; cancel it instead.
     * See instructions/phase-3/03-fix-batch-state-machine.md (Path B).
     * Previously this checked `status !== STATUS_PLANNED`, a state no
     * batch could ever be in (create() always forced in_progress), which
     * made deletion unreachable for every batch that has ever existed.
     */
    public function destroy(ProductionBatch $productionBatch): JsonResponse
    {
        if ($productionBatch->status === ProductionBatch::STATUS_COMPLETED) {
            return response()->json(
                ['message' => 'Completed batches cannot be deleted.'],
                422,
            );
        }

        $this->service->delete($productionBatch);

        return response()->json(['message' => 'Production batch deleted.']);
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
     * GET /production-batches/{productionBatch}/items/{item}
     * Returns full detail for a single batch item (used by QR scanner lookup).
     */
    public function showItem(
        ProductionBatch $productionBatch,
        ProductionBatchItem $item,
    ): JsonResponse {
        if ($item->production_batch_id !== $productionBatch->id) {
            return response()->json(['message' => 'Item does not belong to this batch.'], 404);
        }

        $item->load([
            'productionBatch:id,batch_title,status',
            'variant.productColor.product.productType',
            'variant.productColor.product.productQuality',
            'variant.productColor.color',
            'variant.productSize',
            'variant.productEdge',
            'sourceOrderItem.order.client',
        ]);

        return response()->json(['data' => new ProductionBatchItemResource($item)]);
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

        $updated = $this->service->updateItem($item, $request->validated(), $request->user()->id);

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
                'variant.productEdge',
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
                                ? rtrim(config('app.url'), '/') . '/storage/' . $oi->variant->productColor->image
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
                        'product_edge' => $oi->variant->productEdge
                            ? ['id' => $oi->variant->productEdge->id, 'code' => $oi->variant->productEdge->code, 'title' => $oi->variant->productEdge->title]
                            : null,
                    ],
                ];
            })
            ->filter(fn ($item) => $item['remaining_quantity'] > 0)
            ->values();

        return response()->json(['data' => $orderItems]);
    }

    /**
     * GET /production-batches-labeling-items
     * Returns all items from in_progress batches that are not yet fully labeled (produced).
     */
    public function labelingItems(): JsonResponse
    {
        $items = ProductionBatchItem::with([
                'productionBatch:id,batch_title,status,machine_id',
                'productionBatch.machine:id,name',
                'sourceOrderItem.order.client:id,shop_name',
                'variant.productColor.product.productType',
                'variant.productColor.product.productQuality',
                'variant.productColor.color',
                'variant.productSize',
                'variant.productEdge',
            ])
            ->whereHas('productionBatch', fn ($q) => $q->where('status', ProductionBatch::STATUS_IN_PROGRESS))
            ->get();

        return response()->json([
            'data' => ProductionBatchItemResource::collection($items),
        ]);
    }

    /**
     * POST /production-batches/{productionBatch}/items/{item}/print-label
     * Atomically increments produced_quantity by 1 and mints (or, if
     * `serial` is given and already exists, reprints) a per-carpet unit
     * serial — see instructions/phase-3/02-production-units-serials.md.
     *
     * idempotency_key is optional (nullable) so old app builds that send no
     * body keep working during rollout — see
     * instructions/phase-2/02-idempotency-key.md. A retried print with the
     * same key returns 200 with the unchanged current state instead of
     * incrementing twice.
     *
     * `serial` is also optional and unrelated to idempotency_key: it names
     * an EXISTING unit being relabelled (a jammed printer, a damaged
     * label), not a retry of this request. Old app builds send neither
     * field and get exactly today's behaviour plus a freshly-minted,
     * currently-unused unit row.
     */
    public function printLabel(
        Request $request,
        ProductionBatch $productionBatch,
        ProductionBatchItem $item,
    ): JsonResponse {
        if ($item->production_batch_id !== $productionBatch->id) {
            return response()->json(['message' => 'Item does not belong to this batch.'], 404);
        }

        $validated = $request->validate([
            'idempotency_key' => ['nullable', 'uuid'],
            'serial'          => ['nullable', 'string', 'regex:/^TGC-U-\d{8}$/'],
            // true for a replacement label: recorded, never counted
            'reprint'         => ['sometimes', 'boolean'],
        ]);

        $result = $this->service->incrementProducedQuantity(
            $item,
            $request->user()->id,
            $validated['idempotency_key'] ?? null,
            $validated['serial'] ?? null,
            (bool) ($validated['reprint'] ?? false),
        );

        return response()->json([
            'data'    => new ProductionBatchItemResource($result['item']),
            // false when the print was recorded as a reprint instead of a carpet
            'counted' => $result['counted'],
            'unit' => $result['unit'] ? [
                'serial'        => $result['unit']->serial,
                'reprint_count' => $result['unit']->reprint_count,
            ] : null,
        ]);
    }

    /**
     * GET /production-batches/scan?code={code}
     *
     * Two formats, resolved to the same response shape:
     *   TGC-U-\d{8}                        — a single-carpet unit serial
     *                                         (instructions/phase-3/02).
     *   P{batchId} I{itemId} / PB.. PBI..  — a batch-line code (both
     *                                         accepted since phase-0/11).
     *
     * Correction to the phase-3 brief: unlike when that instruction file
     * was written, the batch-line format is NOT dead — phase-0 already
     * fixed it and it is in active use — so the unit-serial format is
     * added ALONGSIDE it, not as a replacement.
     */
    public function scanItem(Request $request): JsonResponse
    {
        $code = trim((string) $request->input('code'));

        if (preg_match('/^TGC-U-\d{8}$/', $code)) {
            $unit = ProductionUnit::with([
                    'printedByUser',
                    'batchItem.productionBatch' => fn ($q) => $q->with(['machine', 'creator', 'responsibleEmployee']),
                    'batchItem.variant.productColor.product.productType',
                    'batchItem.variant.productColor.product.productQuality',
                    'batchItem.variant.productColor.color',
                    'batchItem.variant.productSize',
                    'batchItem.variant.productEdge',
                    'batchItem.sourceOrderItem.order.client',
                ])
                ->where('serial', $code)
                ->first();

            if (! $unit) {
                return response()->json(['message' => 'Unit not found.'], 404);
            }

            return response()->json(
                $this->buildScanResponse($unit->batchItem, [
                    'serial'          => $unit->serial,
                    'status'          => $unit->status,
                    'printed_at'      => $unit->printed_at?->toISOString(),
                    'printed_by_name' => $unit->printedByUser?->name,
                    'reprint_count'   => $unit->reprint_count,
                ])
            );
        }

        // Accept both formats physically printed on labels:
        //   P{batchId} I{itemId}      — labeling_page.dart, all existing physical labels
        //   PB{batchId} PBI{itemId}   — the originally documented format
        // Anchored, so garbage before/after the code is rejected rather than parsed.
        if (!preg_match('/^P(?:B)?\{?(\d+)\}?\s+(?:PB)?I\{?(\d+)\}?$/i', $code, $matches)) {
            return response()->json(['message' => 'QR kod formati noto\'g\'ri. Kutilgan format: TGC-U-00000000 yoki P{batchId} I{itemId}'], 400);
        }

        $batchId = (int) $matches[1];
        $itemId = (int) $matches[2];

        $item = ProductionBatchItem::with([
                'productionBatch' => fn ($q) => $q->with(['machine', 'creator', 'responsibleEmployee']),
                'variant.productColor.product.productType',
                'variant.productColor.product.productQuality',
                'variant.productColor.color',
                'variant.productSize',
                'variant.productEdge',
                'sourceOrderItem.order.client',
            ])
            ->where('id', $itemId)
            ->where('production_batch_id', $batchId)
            ->first();

        if (!$item) {
            return response()->json(['message' => 'Production item not found.'], 404);
        }

        return response()->json($this->buildScanResponse($item));
    }

    /**
     * Shared by both scan formats. $unit is null for a batch-line scan
     * (the eager-load list is the same either way, with `batchItem.`
     * prepended for the unit path — see scanItem()).
     */
    private function buildScanResponse(ProductionBatchItem $item, ?array $unit = null): array
    {
        $batch = $item->productionBatch;
        $variant = $item->variant;
        $productColor = $variant->productColor;
        $product = $productColor->product;
        $color = $productColor->color;
        $size = $variant->productSize;
        $orderItem = $item->sourceOrderItem;

        return [
            'data' => [
                'unit' => $unit,
                'item' => [
                    'id'                          => $item->id,
                    'planned_quantity'            => $item->planned_quantity,
                    'produced_quantity'           => $item->produced_quantity,
                    'defect_quantity'             => $item->defect_quantity,
                    'warehouse_received_quantity' => $item->warehouse_received_quantity,
                ],
                'product' => [
                    'name'          => $product->name,
                    'quality'       => $product->productQuality?->quality_name,
                    'type'          => $product->productType?->type,
                    'color'         => $color?->name,
                    'color_image'   => $productColor->image
                        ? rtrim(config('app.url'), '/') . '/storage/' . $productColor->image
                        : null,
                    'size_length'   => $size?->length,
                    'size_width'    => $size?->width,
                    'size_label'    => $size ? "{$size->width}×{$size->length}" : null,
                    'barcode'       => $variant->barcode_value,
                    'sku'           => $variant->sku_code,
                ],
                'production_batch' => [
                    'id'                  => $batch->id,
                    'batch_title'         => $batch->batch_title,
                    'status'              => $batch->status,
                    'type'                => $batch->type,
                    'planned_datetime'    => $batch->planned_datetime?->toISOString(),
                    'completed_datetime'  => $batch->completed_datetime?->toISOString(),
                    'machine_id'          => $batch->machine_id,
                    'machine_name'        => $batch->machine?->name,
                    'employee_name'       => $batch->creator?->name,
                    'responsible_employee_name' => $batch->responsibleEmployee?->name,
                    'created_at'          => $batch->created_at?->toISOString(),
                ],
                'destination' => $orderItem?->order?->client ? [
                    'type'             => 'client',
                    'client_name'      => $orderItem->order->client->shop_name,
                    'region'           => $orderItem->order->client->region,
                    'contact_name'     => $orderItem->order->client->contact_name,
                    'phone'            => $orderItem->order->client->phone,
                    'order_id'         => $orderItem->order->id,
                    'order_uuid'       => $orderItem->order->uuid,
                    'order_status'     => $orderItem->order->status,
                    'order_date'       => $orderItem->order->order_date?->toDateString(),
                    'ordered_quantity' => $orderItem->quantity,
                    'shipped_quantity' => (int) $orderItem->shipmentItems()->sum('quantity'),
                ] : [
                    'type' => 'warehouse',
                ],
                'label_prints'   => $this->labelPrints($item),
                'reattribution'  => $this->reattribution($item),
                'stock_quantity' => $this->stockQuantity($item->product_variant_id),
            ],
        ];
    }

    /**
     * Every label printed for this batch line: who and when. The QR on a label
     * names the line, not one carpet, so this is the whole line's history.
     * Lines labelled before 2026-07-20 have backfilled rows with no real
     * printer or time; those are only counted.
     */
    private function labelPrints(ProductionBatchItem $item): array
    {
        $units = ProductionUnit::with('printedByUser:id,name')
            ->where('production_batch_item_id', $item->id)
            ->orderBy('printed_at')
            ->orderBy('id')
            ->get(['id', 'printed_by', 'printed_at', 'backfilled_at']);

        [$backfilled, $recorded] = $units->partition(fn (ProductionUnit $u) => $u->isBackfilled());

        $prints = $recorded->map(fn (ProductionUnit $u) => [
            'printed_at'      => $u->printed_at,
            'printed_by_name' => $u->printedByUser?->name,
            'kind'            => 'print',
        ])->concat(
            LabelReprint::with('printedByUser:id,name')
                ->where('production_batch_item_id', $item->id)
                ->get()
                ->map(fn (LabelReprint $r) => [
                    'printed_at'      => $r->printed_at,
                    'printed_by_name' => $r->printedByUser?->name,
                    'kind'            => $r->reason,
                ])
        );

        return [
            'before_tracking' => $backfilled->count(),
            // kind: print (a counted carpet), reprint, over_target
            'prints'          => $prints->sortBy(fn (array $p) => $p['printed_at'])->values()
                ->map(fn (array $p) => [...$p, 'printed_at' => $p['printed_at']?->toISOString()])
                ->all(),
        ];
    }

    /** Set when a shipment took this line's carpets from another client's order. */
    private function reattribution(ProductionBatchItem $item): ?array
    {
        if ($item->reattributed_from_order_item_id === null) {
            return null;
        }

        $from = OrderItem::with('order.client:id,shop_name')->find($item->reattributed_from_order_item_id);

        return [
            'from_client_name' => $from?->order?->client?->shop_name,
            'shipment_id'      => $item->reattributed_by_shipment_id,
        ];
    }

    /** Warehouse stock of this product right now, counted the way shipments count it. */
    private function stockQuantity(int $variantId): int
    {
        $row = DB::table('stock_movements')
            ->where('product_variant_id', $variantId)
            ->selectRaw('COALESCE(SUM(CASE WHEN movement_type = ? THEN quantity ELSE 0 END), 0) AS qty_in', [StockMovement::TYPE_IN])
            ->selectRaw('COALESCE(SUM(CASE WHEN movement_type = ? THEN quantity ELSE 0 END), 0) AS qty_out', [StockMovement::TYPE_OUT])
            ->first();

        return (int) $row->qty_in - (int) $row->qty_out;
    }
}
