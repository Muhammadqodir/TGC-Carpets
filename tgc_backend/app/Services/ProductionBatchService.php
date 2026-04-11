<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use Illuminate\Support\Facades\DB;

class ProductionBatchService
{
    private const EAGER_LOAD = [
        'machine',
        'creator',
        'items.variant.productColor.product.productType',
        'items.variant.productColor.product.productQuality',
        'items.variant.productColor.color',
        'items.variant.productSize',
        'items.sourceOrderItem.order.client',
    ];

    public function __construct(
        private readonly ProductVariantService $variantService,
    ) {}

    /**
     * Create a production batch with its items.
     */
    public function create(array $data, int $userId): ProductionBatch
    {
        return DB::transaction(function () use ($data, $userId): ProductionBatch {
            $batch = ProductionBatch::create([
                'batch_title'      => $data['batch_title'],
                'planned_datetime' => $data['planned_datetime'] ?? null,
                'machine_id'       => $data['machine_id'],
                'type'             => $data['type'] ?? ProductionBatch::TYPE_BY_ORDER,
                'status'           => ProductionBatch::STATUS_PLANNED,
                'created_by'       => $userId,
                'notes'            => $data['notes'] ?? null,
            ]);

            if (! empty($data['items'])) {
                $this->syncItems($batch, $data['items']);
                $this->syncOrderStatuses($batch);
            }

            return $batch->load(self::EAGER_LOAD);
        });
    }

    /**
     * Update batch header and optionally replace items.
     */
    public function update(ProductionBatch $batch, array $data): ProductionBatch
    {
        return DB::transaction(function () use ($batch, $data): ProductionBatch {
            $batch->update(array_filter([
                'batch_title'      => $data['batch_title'] ?? null,
                'planned_datetime' => array_key_exists('planned_datetime', $data) ? $data['planned_datetime'] : null,
                'machine_id'       => $data['machine_id'] ?? null,
                'type'             => $data['type'] ?? null,
                'notes'            => array_key_exists('notes', $data) ? $data['notes'] : null,
            ], fn ($v) => $v !== null));

            if (isset($data['items'])) {
                // Remove old items and re-sync
                $batch->items()->delete();
                $this->syncItems($batch, $data['items']);
                $this->syncOrderStatuses($batch);
            }

            return $batch->fresh()->load(self::EAGER_LOAD);
        });
    }

    /**
     * Start production — transition from planned → in_progress.
     */
    public function start(ProductionBatch $batch): ProductionBatch
    {
        DB::transaction(function () use ($batch): void {
            $batch->update([
                'status'           => ProductionBatch::STATUS_IN_PROGRESS,
                'started_datetime' => now(),
            ]);

            // Move all fully-planned linked orders to on_production.
            $orderIds = $batch->items()
                ->whereNotNull('source_order_item_id')
                ->with('sourceOrderItem')
                ->get()
                ->pluck('sourceOrderItem.order_id')
                ->filter()
                ->unique();

            if ($orderIds->isNotEmpty()) {
                Order::whereIn('id', $orderIds)
                    ->where('status', Order::STATUS_PLANNED)
                    ->update(['status' => Order::STATUS_ON_PRODUCTION]);
            }
        });

        return $batch->fresh()->load(self::EAGER_LOAD);
    }

    /**
     * Complete production — transition from in_progress → completed.
     */
    public function complete(ProductionBatch $batch): ProductionBatch
    {
        $batch->update([
            'status'             => ProductionBatch::STATUS_COMPLETED,
            'completed_datetime' => now(),
        ]);

        return $batch->fresh()->load(self::EAGER_LOAD);
    }

    /**
     * Cancel production batch.
     */
    public function cancel(ProductionBatch $batch): ProductionBatch
    {
        $batch->update([
            'status' => ProductionBatch::STATUS_CANCELLED,
        ]);

        return $batch->fresh()->load(self::EAGER_LOAD);
    }

    /**
     * Update quantities on a single batch item (during production).
     */
    public function updateItem(ProductionBatchItem $item, array $data): ProductionBatchItem
    {
        $item->update(array_filter([
            'produced_quantity' => $data['produced_quantity'] ?? null,
            'defect_quantity'   => $data['defect_quantity'] ?? null,
            'notes'             => array_key_exists('notes', $data) ? $data['notes'] : null,
        ], fn ($v) => $v !== null));

        return $item->fresh()->load([
            'variant.productColor.product.productType',
            'variant.productColor.product.productQuality',
            'variant.productColor.color',
            'variant.productSize',
            'sourceOrderItem.order.client',
        ]);
    }

    /**
     * Delete a production batch and its items.
     */
    public function delete(ProductionBatch $batch): void
    {
        DB::transaction(function () use ($batch): void {
            $batch->items()->delete();
            $batch->delete();
        });
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function syncItems(ProductionBatch $batch, array $items): void
    {
        foreach ($items as $itemData) {
            if (!empty($itemData['product_variant_id'])) {
                $variantId = (int) $itemData['product_variant_id'];
            } else {
                $variantId = $this->variantService->findOrCreate(
                    (int) $itemData['product_color_id'],
                    !empty($itemData['product_size_id']) ? (int) $itemData['product_size_id'] : null,
                )->id;
            }

            $batch->items()->create([
                'source_type'           => $itemData['source_type'] ?? ProductionBatchItem::SOURCE_MANUAL,
                'source_order_item_id'  => $itemData['source_order_item_id'] ?? null,
                'product_variant_id'    => $variantId,
                'planned_quantity'      => $itemData['planned_quantity'],
                'notes'                 => $itemData['notes'] ?? null,
            ]);
        }
    }

    /**
     * After syncing items, check if any linked orders should transition to planned.
     * An order moves to planned when every one of its items has enough planned quantity
     * across all non-cancelled batches.
     */
    private function syncOrderStatuses(ProductionBatch $batch): void
    {
        $orderIds = $batch->items()
            ->whereNotNull('source_order_item_id')
            ->with('sourceOrderItem')
            ->get()
            ->pluck('sourceOrderItem.order_id')
            ->filter()
            ->unique();

        foreach ($orderIds as $orderId) {
            $order = Order::with('items')->find($orderId);
            if (!$order || $order->status !== Order::STATUS_PENDING) {
                continue;
            }

            $allCovered = $order->items->every(function (OrderItem $item) {
                $planned = ProductionBatchItem::where('source_order_item_id', $item->id)
                    ->whereHas('productionBatch', fn ($q) => $q->where('status', '!=', ProductionBatch::STATUS_CANCELLED))
                    ->sum('planned_quantity');

                return $planned >= $item->quantity;
            });

            if ($allCovered) {
                $order->update(['status' => Order::STATUS_PLANNED]);
            }
        }
    }
}
