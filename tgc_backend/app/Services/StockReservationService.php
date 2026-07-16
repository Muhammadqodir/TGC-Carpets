<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\StockReservation;
use Illuminate\Support\Facades\DB;

/**
 * physical  = SUM(stock_movements: in - out)                        — what is in the building
 * reserved  = SUM(stock_reservations.quantity WHERE status='active') — what is promised
 * available = physical - reserved                                   — what can be promised
 *
 * available may be negative — that is a real backorder, not an error, and
 * must never be clamped to zero. See
 * instructions/phase-3/07-stock-reservations.md.
 *
 * Ships in warn-only mode: nothing here rejects an order or a shipment.
 * Orders are always accepted even when they push `available` negative —
 * "12 available, 80 ordered, 68 to produce" is the business, not an error
 * state. A hard block is a deliberately separate, later, unscheduled
 * decision — see the instruction file's "Rollout".
 */
class StockReservationService
{
    /**
     * One row per order line. Called from OrderService::syncItems() for
     * every order item created — including on a full item replace, where
     * the old items (and, via cascadeOnDelete, their reservations) were
     * just hard-deleted and new ones take their place.
     */
    public function reserveForOrderItem(OrderItem $orderItem, int $userId): StockReservation
    {
        return StockReservation::create([
            'product_variant_id' => $orderItem->product_variant_id,
            'order_item_id'      => $orderItem->id,
            'quantity'           => $orderItem->quantity,
            'status'             => StockReservation::STATUS_ACTIVE,
            'reserved_by'        => $userId,
            'reserved_at'        => now(),
        ]);
    }

    /**
     * Release every active reservation on an order (cancellation). Marks
     * released with a reason rather than deleting — the reservation
     * history is how "why did this order lose its claim" gets answered
     * later, and 06-audit-log.md does not cover a row that never existed.
     */
    public function releaseForOrder(Order $order, string $reason): void
    {
        DB::transaction(function () use ($order, $reason): void {
            StockReservation::whereIn('order_item_id', $order->items()->pluck('id'))
                ->where('status', StockReservation::STATUS_ACTIVE)
                ->update([
                    'status'         => StockReservation::STATUS_RELEASED,
                    'released_at'    => now(),
                    'release_reason' => $reason,
                ]);
        });
    }

    /**
     * Called when a shipment ships against an order line. Reduces the
     * active reservation by the shipped quantity, or marks it fulfilled
     * once fully consumed. Invariant: shipping must reduce `physical`
     * (via the normal stock_movement path) and `reserved` by the same
     * amount, so `available` does not move — the goods left, but so did
     * the claim on them.
     *
     * A missing reservation (order item created before this feature
     * shipped, or already fulfilled/released) is not an error — shipping
     * must never be blocked by a reservation bookkeeping gap. It is
     * silently a no-op, same as $qty <= 0.
     */
    public function consumeForOrderItem(int $orderItemId, int $shippedQty): void
    {
        if ($shippedQty <= 0) {
            return;
        }

        DB::transaction(function () use ($orderItemId, $shippedQty): void {
            $reservation = StockReservation::where('order_item_id', $orderItemId)
                ->where('status', StockReservation::STATUS_ACTIVE)
                ->lockForUpdate()
                ->first();

            if (! $reservation) {
                return;
            }

            $remaining = $reservation->quantity - $shippedQty;

            if ($remaining <= 0) {
                $reservation->update([
                    'quantity'    => 0,
                    'status'      => StockReservation::STATUS_FULFILLED,
                    'released_at' => now(),
                ]);
            } else {
                $reservation->update(['quantity' => $remaining]);
            }
        });
    }

    /** SUM(active reservations) for one variant — the `reserved` term of `available`. */
    public function reservedQuantityForVariant(int $variantId): int
    {
        return (int) StockReservation::where('product_variant_id', $variantId)
            ->where('status', StockReservation::STATUS_ACTIVE)
            ->sum('quantity');
    }

    /** [variant_id => reserved_quantity] for a set of variants, one query. */
    public function reservedQuantitiesForVariants(array $variantIds): array
    {
        if ($variantIds === []) {
            return [];
        }

        return StockReservation::whereIn('product_variant_id', $variantIds)
            ->where('status', StockReservation::STATUS_ACTIVE)
            ->groupBy('product_variant_id')
            ->selectRaw('product_variant_id, SUM(quantity) as total')
            ->pluck('total', 'product_variant_id')
            ->map(fn ($v) => (int) $v)
            ->all();
    }
}
