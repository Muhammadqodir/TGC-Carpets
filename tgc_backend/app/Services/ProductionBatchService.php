<?php

namespace App\Services;

use App\Models\LabelReprint;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use App\Models\ProductionUnit;
use Illuminate\Database\QueryException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class ProductionBatchService
{
    private const EAGER_LOAD = [
        'machine',
        'creator',
        'responsibleEmployee',
        'items.variant.productColor.product.productType',
        'items.variant.productColor.product.productQuality',
        'items.variant.productColor.color',
        'items.variant.productSize',
        'items.variant.productEdge',
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
                'batch_title'             => $data['batch_title'],
                'planned_datetime'        => $data['planned_datetime'] ?? null,
                'machine_id'              => $data['machine_id'],
                'type'                    => $data['type'] ?? ProductionBatch::TYPE_BY_ORDER,
                'status'                  => ProductionBatch::STATUS_IN_PROGRESS,
                'started_datetime'        => now(),
                'responsible_employee_id' => $userId,
                'created_by'              => $userId,
                'notes'                   => $data['notes'] ?? null,
            ]);

            if (! empty($data['items'])) {
                $this->syncItems($batch, $data['items']);
                $this->syncOrderStatuses($batch);

                // Move any linked pending/planned orders to on_production immediately.
                $orderIds = $batch->items()
                    ->whereNotNull('source_order_item_id')
                    ->with('sourceOrderItem')
                    ->get()
                    ->pluck('sourceOrderItem.order_id')
                    ->filter()
                    ->unique();

                if ($orderIds->isNotEmpty()) {
                    Order::whereIn('id', $orderIds)
                        ->whereIn('status', [Order::STATUS_PENDING, Order::STATUS_PLANNED])
                        ->update(['status' => Order::STATUS_ON_PRODUCTION]);
                }
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
                $this->assertNoRecordedProduction($batch);

                // Remove old items and re-sync
                $batch->items()->delete();
                $this->syncItems($batch, $data['items']);
                $this->syncOrderStatuses($batch);
            }

            return $batch->fresh()->load(self::EAGER_LOAD);
        });
    }

    /**
     * Refuse to replace a batch's items once any of them has recorded
     * production — deleting and re-creating resets produced_quantity,
     * defect_quantity and warehouse_received_quantity to 0, orphans printed
     * QR labels (which encode the item id), and can hit an FK RESTRICT from
     * defect_document_items. See instructions/phase-0/06.
     */
    private function assertNoRecordedProduction(ProductionBatch $batch): void
    {
        $hasProduction = $batch->items()
            ->where(function ($q) {
                $q->where('produced_quantity', '>', 0)
                    ->orWhere('defect_quantity', '>', 0)
                    ->orWhere('warehouse_received_quantity', '>', 0);
            })
            ->exists();

        if ($hasProduction) {
            throw ValidationException::withMessages([
                'items' => 'Ishlab chiqarish boshlangan partiya mahsulotlarini o\'zgartirib bo\'lmaydi.',
            ]);
        }
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
     * Cancel production batch and revert any linked orders that are no longer
     * fully covered by active batches back to pending.
     */
    public function cancel(ProductionBatch $batch): ProductionBatch
    {
        return DB::transaction(function () use ($batch): ProductionBatch {
            $batch->update([
                'status' => ProductionBatch::STATUS_CANCELLED,
            ]);

            $this->revertOrderStatusesOnCancel($batch);

            return $batch->fresh()->load(self::EAGER_LOAD);
        });
    }

    /**
     * Atomically increment produced_quantity by 1 (label print action),
     * append a 'produced' event to the log (instructions/phase-2/01), and
     * mint or reuse a ProductionUnit serial (instructions/phase-3/02) — all
     * in the same transaction.
     *
     * When $idempotencyKey is given, a retried print with the same key is a
     * no-op replay: the unique index (not a SELECT-then-insert, which races)
     * detects the duplicate and the method returns the current state without
     * incrementing a second time. See
     * instructions/phase-2/02-idempotency-key.md. KNOWN GAP: on a replay,
     * $unit in the return value is null — the caller cannot recover the
     * serial minted on the original (successful) attempt from here. This
     * only matters if a client retries after genuinely never seeing the
     * first response; accepted rather than adding a second lookup column,
     * see instructions/phase-3/02's own "Do not compress it" rollout order.
     *
     * When $serial is given and an existing unit with that serial is
     * found, this is a REPRINT: reprint_count++, no counter change, no
     * event — printing the same physical carpet's label again must never
     * double-count it. This is the bug 02-production-units-serials.md
     * exists to fix: today's blind increment() cannot tell a reprint from
     * a new carpet.
     *
     * A label that is not a new carpet never counts. With $reprint (the
     * worker replacing a torn or misprinted label), or once the line already
     * has produced_quantity >= planned_quantity - defect_quantity (a double
     * click, or a print past the plan), the print is recorded in
     * label_reprints — who and when — and produced_quantity stays put. Seven
     * lines were over-counted by double clicks before this, see
     * production:fix-over-target.
     *
     * After incrementing, checks whether all items in the batch have
     * produced_quantity >= (planned_quantity - defect_quantity).
     * If so, the batch is automatically transitioned to completed.
     *
     * $printedAt is when the label physically came out of the printer. The
     * app prints first and sends the record from an offline queue, so the
     * request can arrive minutes or hours later; the event, unit and reprint
     * rows are dated by the print, not by the request. Null = now.
     *
     * $carpetNumber is the number printed on this label (see CarpetNumberBlock).
     * The label is already out of the printer, so a problem with the number must
     * never lose the carpet: a number another carpet already has is logged and
     * left off, and the carpet still counts.
     *
     * $lengthCm is the real length printed on the label of a carpet whose type
     * has a variable length (Kovrolin), stored on the event, the unit and the
     * reprint row. Null = the size's nominal length.
     *
     * @return array{item: ProductionBatchItem, unit: ?ProductionUnit, counted: bool}
     */
    public function incrementProducedQuantity(
        ProductionBatchItem $item,
        int $userId,
        ?string $idempotencyKey = null,
        ?string $serial = null,
        bool $reprint = false,
        ?\DateTimeInterface $printedAt = null,
        ?string $carpetNumber = null,
        ?int $lengthCm = null,
    ): array {
        $unit    = null;
        $counted = false;
        $at      = $printedAt ?? now();

        DB::transaction(function () use ($item, $userId, $idempotencyKey, $serial, $reprint, $at, $carpetNumber, $lengthCm, &$unit, &$counted): void {
            // A deadlock retry runs this again from the top.
            $unit    = null;
            $counted = false;

            // Lock the batch item before anything else. Without it, two prints
            // of the same item — a double tap, or a retry racing the original —
            // each took a shared lock on this row through the production_events
            // foreign key, then each needed an exclusive one to increment
            // produced_quantity: a deadlock, surfacing as a 500 on print-label
            // several times a week in September 2026. Taken first, the second
            // print simply waits, then counts (or, with the same idempotency
            // key, replays) against the committed first.
            $locked = ProductionBatchItem::whereKey($item->id)->lockForUpdate()->first();

            if ($serial !== null) {
                $existing = ProductionUnit::where('serial', $serial)->lockForUpdate()->first();
                if ($existing) {
                    $existing->increment('reprint_count');
                    $unit = $existing->fresh();

                    return;
                }
            }

            // A retry of a request that already went through replays it,
            // whichever way it went: checked before the plan, because the
            // retry of the print that met the plan finds the line full.
            if ($idempotencyKey !== null) {
                if (ProductionEvent::where('idempotency_key', $idempotencyKey)->exists()) {
                    $counted = true;

                    return;
                }
                if (LabelReprint::where('idempotency_key', $idempotencyKey)->exists()) {
                    return;
                }
            }

            $planMet = $locked->produced_quantity >= $locked->planned_quantity - $locked->defect_quantity;

            if ($reprint || $planMet) {
                try {
                    LabelReprint::create([
                        'production_batch_item_id' => $item->id,
                        'printed_by'               => $userId,
                        'printed_at'               => $at,
                        'reason'                   => $reprint ? LabelReprint::REASON_REPRINT : LabelReprint::REASON_OVER_TARGET,
                        'carpet_number'            => $carpetNumber,
                        'length_cm'                => $lengthCm,
                        'idempotency_key'          => $idempotencyKey,
                    ]);
                } catch (QueryException $e) {
                    if (! $this->isDuplicateKey($e)) {
                        throw $e;
                    }
                }

                return;
            }

            $eventData = [
                'production_batch_item_id' => $item->id,
                'event_type'               => ProductionEvent::TYPE_PRODUCED,
                'quantity'                 => 1,
                'length_cm'                => $lengthCm,
                'occurred_at'              => $at,
                'user_id'                  => $userId,
                'idempotency_key'          => $idempotencyKey,
                'created_at'               => now(),
            ];

            if ($idempotencyKey !== null) {
                try {
                    ProductionEvent::create($eventData);
                } catch (QueryException $e) {
                    if ($this->isDuplicateKey($e)) {
                        return;   // replay: event already recorded, do NOT increment or mint
                    }
                    throw $e;
                }
            } else {
                // Legacy client: no key. Record the event, accept the double-count risk.
                ProductionEvent::create($eventData);
            }

            $item->increment('produced_quantity');
            $counted = true;

            $newUnit = ProductionUnit::create([
                'production_batch_item_id' => $item->id,
                'serial'                   => 'PENDING',
                'carpet_number'            => $this->unusedCarpetNumber($carpetNumber, $item->id),
                'length_cm'                => $lengthCm,
                'printed_by'               => $userId,
                'printed_at'               => $at,
                'status'                   => ProductionUnit::STATUS_GOOD,
            ]);
            // Two-step: the serial derives from the auto-increment id, and
            // `serial` is NOT NULL UNIQUE, so 'PENDING' can only ever exist
            // for one row at a time inside a transaction — exactly the
            // serialisation that prevents two concurrent prints from
            // colliding. See instructions/phase-3/02 "Print becomes
            // idempotent" for the contention note if this ever needs to
            // become a sequence table instead.
            $newUnit->update(['serial' => sprintf('TGC-U-%08d', $newUnit->id)]);
            $unit = $newUnit;

            $batch = ProductionBatch::lockForUpdate()->find($item->production_batch_id);

            if ($batch && $batch->status === ProductionBatch::STATUS_IN_PROGRESS) {
                $allLabeled = ! $batch->items()
                    ->whereRaw('produced_quantity < (planned_quantity - defect_quantity)')
                    ->exists();

                if ($allLabeled) {
                    $batch->update([
                        'status'             => ProductionBatch::STATUS_COMPLETED,
                        'completed_datetime' => now(),
                    ]);
                }
            }
        }, 3);   // a deadlock victim is retried whole instead of failing the print

        $freshItem = $item->fresh()->load([
            'productionBatch',
            'variant.productColor.product.productType',
            'variant.productColor.product.productQuality',
            'variant.productColor.color',
            'variant.productSize',
            'variant.productEdge',
            'sourceOrderItem.order.client',
        ]);

        return ['item' => $freshItem, 'unit' => $unit, 'counted' => $counted];
    }

    /**
     * $number, unless another carpet already has it. That should never happen:
     * it would take a PC's saved numbers being copied to another PC. Two labels
     * in the same race reach the unique index instead; the request fails, the
     * app sends it again, and this check catches it then.
     */
    private function unusedCarpetNumber(?string $number, int $itemId): ?string
    {
        if ($number === null || ! ProductionUnit::where('carpet_number', $number)->exists()) {
            return $number;
        }

        Log::warning('Carpet number already used by another carpet', [
            'carpet_number'            => $number,
            'production_batch_item_id' => $itemId,
        ]);

        return null;
    }

    /** How long after printing a label the shift can still take it back. */
    public const UNDO_WINDOW_HOURS = 24;

    /**
     * Takes back a label printed by mistake, by the idempotency key it was
     * printed with: the carpet stops counting as produced.
     *
     * The ledger stays append-only. A -1 'correction' event with reason
     * "undo:{key}" cancels the 'produced' event, dated and attributed like
     * it so the shift and the hour lose exactly that carpet; the counter
     * goes down by one; the label's unit is marked scrapped (the worker
     * throws the label away). A batch that the print completed goes back to
     * in progress.
     *
     * Allowed only for the account that printed it, within
     * UNDO_WINDOW_HOURS, and while the carpet is still on the floor (not
     * received into the warehouse or shipped). Repeating an undo is a no-op,
     * so the app's queue can resend it safely.
     *
     * @return array{status: 'undone'|'already_undone'|'not_counted'|'not_found', item: ?ProductionBatchItem}
     */
    public function undoLabelPrint(string $key, int $userId): array
    {
        $status = 'not_found';
        $itemId = null;

        DB::transaction(function () use ($key, $userId, &$status, &$itemId): void {
            $status = 'not_found';
            $itemId = null;

            $event = ProductionEvent::where('idempotency_key', $key)->first();

            if (! $event) {
                // A reprint or a print past the plan never counted, so there
                // is no carpet to take back.
                $reprint = LabelReprint::where('idempotency_key', $key)->first();
                if ($reprint) {
                    $status = 'not_counted';
                    $itemId = $reprint->production_batch_item_id;
                }

                return;
            }

            $itemId = $event->production_batch_item_id;

            if ($event->event_type !== ProductionEvent::TYPE_PRODUCED) {
                $status = 'not_counted';

                return;
            }

            // Same lock order as incrementProducedQuantity(): the line first.
            $locked = ProductionBatchItem::whereKey($itemId)->lockForUpdate()->first();
            $reason = ProductionEvent::UNDO_REASON_PREFIX . $key;

            if (ProductionEvent::where('production_batch_item_id', $itemId)
                ->where('event_type', ProductionEvent::TYPE_CORRECTION)
                ->where('reason', $reason)
                ->exists()) {
                $status = 'already_undone';

                return;
            }

            if ((int) $event->user_id !== $userId) {
                throw ValidationException::withMessages(['key' => [
                    "Bu yorliqni boshqa smena chop etgan. Uni faqat o'sha smena bekor qila oladi.",
                ]]);
            }

            if (Carbon::parse($event->occurred_at)->lt(now()->subHours(self::UNDO_WINDOW_HOURS))) {
                throw ValidationException::withMessages(['key' => [
                    'Yorliq ' . self::UNDO_WINDOW_HOURS . " soatdan oldin chop etilgan, endi bekor qilib bo'lmaydi.",
                ]]);
            }

            if ($locked->produced_quantity <= 0) {
                throw ValidationException::withMessages(['key' => [
                    "Bu qatorda bekor qilinadigan gilam qolmagan (boshqa buyurtmaga o'tkazilgan bo'lishi mumkin).",
                ]]);
            }

            // The unit minted with this print: same line, printer and second.
            // Two prints in one second share these, so take one still on the
            // floor.
            $unit = ProductionUnit::where('production_batch_item_id', $itemId)
                ->where('printed_by', $event->user_id)
                ->where('printed_at', $event->occurred_at)
                ->orderByRaw('status = ? DESC', [ProductionUnit::STATUS_GOOD])
                ->orderByDesc('id')
                ->lockForUpdate()
                ->first();

            if ($unit && in_array($unit->status, [ProductionUnit::STATUS_RECEIVED, ProductionUnit::STATUS_SHIPPED], true)) {
                throw ValidationException::withMessages(['key' => [
                    $unit->status === ProductionUnit::STATUS_SHIPPED
                        ? "Bu gilam allaqachon yuk xati bilan jo'natilgan, bekor qilib bo'lmaydi."
                        : "Bu gilam allaqachon omborga qabul qilingan, bekor qilib bo'lmaydi.",
                ]]);
            }

            $batch = ProductionBatch::lockForUpdate()->find($locked->production_batch_id);
            $wasAllLabeled = $batch && ! $batch->items()
                ->whereRaw('produced_quantity < (planned_quantity - defect_quantity)')
                ->exists();

            ProductionEvent::create([
                'production_batch_item_id' => $itemId,
                'event_type'               => ProductionEvent::TYPE_CORRECTION,
                'quantity'                 => -1,
                // the same roll's length, so production m² loses exactly it
                'length_cm'                => $event->length_cm,
                'occurred_at'              => $event->occurred_at,
                'user_id'                  => $event->user_id,
                'reason'                   => $reason,
                'created_at'               => now(),
            ]);
            $locked->decrement('produced_quantity');

            if ($unit && $unit->status === ProductionUnit::STATUS_GOOD) {
                $unit->update(['status' => ProductionUnit::STATUS_SCRAPPED]);
            }

            // Only a batch this line's labels completed reopens: one closed
            // by hand with lines still short stays closed.
            if ($batch && $wasAllLabeled && $batch->status === ProductionBatch::STATUS_COMPLETED) {
                $batch->update([
                    'status'             => ProductionBatch::STATUS_IN_PROGRESS,
                    'completed_datetime' => null,
                ]);
            }

            $status = 'undone';

            Log::info('production.label_print_undone', [
                'production_batch_item_id' => $itemId,
                'event_id'                 => $event->id,
                'unit_id'                  => $unit?->id,
                'user_id'                  => $userId,
            ]);
        });

        $item = $itemId === null ? null : ProductionBatchItem::find($itemId)?->load([
            'productionBatch',
            'variant.productColor.product.productType',
            'variant.productColor.product.productQuality',
            'variant.productColor.color',
            'variant.productSize',
            'variant.productEdge',
            'sourceOrderItem.order.client',
        ]);

        return ['status' => $status, 'item' => $item];
    }

    private function isDuplicateKey(QueryException $e): bool
    {
        return ($e->errorInfo[1] ?? null) === 1062;   // MySQL ER_DUP_ENTRY
    }

    /**
     * Update quantities on a single batch item (during production).
     *
     * This sets counters directly from a manual form, with no event behind
     * it by construction. Per instructions/phase-2/06-production-reconcile-command.md
     * §5, every call here is guaranteed drift unless it appends a
     * 'correction'/'defect' event for the delta itself — so it does, inside
     * the same locked transaction, before writing the new value. This turns
     * a silent manual override into an auditable adjustment.
     */
    public function updateItem(ProductionBatchItem $item, array $data, int $userId): ProductionBatchItem
    {
        DB::transaction(function () use ($item, $data, $userId): void {
            $locked = ProductionBatchItem::lockForUpdate()->find($item->id);

            $updates = [];

            if (array_key_exists('produced_quantity', $data) && $data['produced_quantity'] !== null) {
                $delta = (int) $data['produced_quantity'] - $locked->produced_quantity;
                if ($delta !== 0) {
                    ProductionEvent::create([
                        'production_batch_item_id' => $locked->id,
                        'event_type'               => ProductionEvent::TYPE_CORRECTION,
                        'quantity'                 => $delta,
                        'occurred_at'              => now(),
                        'user_id'                  => $userId,
                        'reason'                   => 'manual adjustment via production-batches items.update',
                        'created_at'               => now(),
                    ]);
                }
                $updates['produced_quantity'] = $data['produced_quantity'];
            }

            if (array_key_exists('defect_quantity', $data) && $data['defect_quantity'] !== null) {
                $delta = (int) $data['defect_quantity'] - $locked->defect_quantity;
                if ($delta !== 0) {
                    ProductionEvent::create([
                        'production_batch_item_id' => $locked->id,
                        'event_type'               => ProductionEvent::TYPE_DEFECT,
                        'quantity'                 => $delta,
                        'occurred_at'              => now(),
                        'user_id'                  => $userId,
                        'reason'                   => 'manual adjustment via production-batches items.update',
                        'created_at'               => now(),
                    ]);
                }
                $updates['defect_quantity'] = $data['defect_quantity'];
            }

            if (array_key_exists('notes', $data) && $data['notes'] !== null) {
                $updates['notes'] = $data['notes'];
            }

            if ($updates !== []) {
                $locked->update($updates);
            }
        });

        return $item->fresh()->load([
            'variant.productColor.product.productType',
            'variant.productColor.product.productQuality',
            'variant.productColor.color',
            'variant.productSize',
            'variant.productEdge',
            'sourceOrderItem.order.client',
        ]);
    }

    /**
     * Delete a production batch and its items.
     * Reverts linked order statuses before removing records so the order
     * coverage check can still read the items that are about to be deleted.
     */
    public function delete(ProductionBatch $batch): void
    {
        DB::transaction(function () use ($batch): void {
            $this->assertNoRecordedProduction($batch);

            // Must run before items are deleted so the coverage query still works.
            $this->revertOrderStatusesOnCancel($batch);
            $batch->items()->delete();
            $batch->delete();
        });
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function syncItems(ProductionBatch $batch, array $items): void
    {
        // Pre-load all referenced order items in one query to avoid N+1.
        $orderItemIds = collect($items)
            ->pluck('source_order_item_id')
            ->filter()
            ->unique()
            ->values()
            ->all();

        $orderItemVariants = $orderItemIds
            ? OrderItem::whereIn('id', $orderItemIds)->pluck('product_variant_id', 'id')
            : collect();

        foreach ($items as $itemData) {
            if (!empty($itemData['product_variant_id'])) {
                $variantId = (int) $itemData['product_variant_id'];
            } elseif (!empty($itemData['source_order_item_id']) && isset($orderItemVariants[$itemData['source_order_item_id']])) {
                // Use the order item's variant directly so the correct edge is
                // always applied, even when the client omits product_edge_id.
                $variantId = (int) $orderItemVariants[$itemData['source_order_item_id']];
            } else {
                $variantId = $this->variantService->findOrCreate(
                    (int) $itemData['product_color_id'],
                    !empty($itemData['product_size_id']) ? (int) $itemData['product_size_id'] : null,
                    !empty($itemData['product_edge_id']) ? (int) $itemData['product_edge_id'] : null,
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

    /**
     * After cancelling a batch, revert linked orders to pending if any of their
     * items are no longer fully covered by remaining active (non-cancelled) batches.
     * Orders that are already done or canceled are left untouched.
     */
    private function revertOrderStatusesOnCancel(ProductionBatch $batch): void
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

            if (! $order || in_array($order->status, [Order::STATUS_DONE, Order::STATUS_CANCELED])) {
                continue;
            }

            // An order should revert to pending when at least one item is no
            // longer fully covered by any active (non-cancelled) production batch.
            $allCovered = $order->items->every(function (OrderItem $item) {
                $planned = ProductionBatchItem::where('source_order_item_id', $item->id)
                    ->whereHas('productionBatch', fn ($q) => $q->where('status', '!=', ProductionBatch::STATUS_CANCELLED))
                    ->sum('planned_quantity');

                return $planned >= $item->quantity;
            });

            if (! $allCovered) {
                $order->update(['status' => Order::STATUS_PENDING]);
            }
        }
    }
}
