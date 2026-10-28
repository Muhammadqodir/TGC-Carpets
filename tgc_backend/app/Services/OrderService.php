<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Facades\DB;

class OrderService
{
    public function __construct(
        private readonly ProductVariantService $variantService,
        private readonly StockReservationService $reservationService,
    ) {}

    /**
     * Create an order with items.
     * Supports idempotent creation via external_uuid.
     */
    public function create(array $data, int $userId): Order
    {
        if (! empty($data['external_uuid'])) {
            $existing = Order::where('external_uuid', $data['external_uuid'])->first();
            if ($existing) {
                return $existing->load(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge']);
            }
        }

        return DB::transaction(function () use ($data, $userId): Order {
            $order = Order::create([
                'external_uuid' => $data['external_uuid'] ?? null,
                'user_id'       => $userId,
                'client_id'     => $data['client_id'] ?? null,
                'status'        => $data['status'] ?? Order::STATUS_PENDING,
                'order_date'    => $data['order_date'],
                'notes'         => $data['notes'] ?? null,
            ]);

            $this->syncItems($order, $data['items'], $userId);

            return $order->load(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge']);
        });
    }

    /**
     * Update order header fields and optionally replace all items.
     */
    public function update(Order $order, array $data, int $userId): Order
    {
        return DB::transaction(function () use ($order, $data, $userId): Order {
            $wasCanceled = $order->status === Order::STATUS_CANCELED;

            $order->update(array_filter([
                'client_id'  => array_key_exists('client_id', $data) ? $data['client_id'] : null,
                'status'     => $data['status']     ?? null,
                'order_date' => $data['order_date'] ?? null,
                'notes'      => array_key_exists('notes', $data) ? $data['notes'] : null,
            ], fn ($v) => $v !== null));

            // Release every active reservation the moment an order is
            // cancelled — a cancelled order must stop claiming stock other
            // orders could use. See
            // instructions/phase-3/07-stock-reservations.md.
            if (! $wasCanceled && $order->status === Order::STATUS_CANCELED) {
                $this->reservationService->releaseForOrder($order, 'order_cancelled');
            }

            if (! empty($data['items'])) {
                // Guard: shipment_items references order_items with restrictOnDelete.
                // Deleting shipped line items would violate the FK constraint.
                if ($order->items()->whereHas('shipmentItems')->exists()) {
                    throw new \DomainException(
                        'Buyurtma qatorlari yuk xatiga kiritilgan. Mahsulot ro\'yxatini o\'zgartirib bo\'lmaydi.'
                    );
                }

                // Guard: production_batch_items.source_order_item_id is
                // nullOnDelete, so deleting order items here would not error —
                // it would silently sever the link to whatever's already been
                // produced against them (the production_batch_items rows and
                // their quantities survive, just orphaned). The order then
                // gets fresh item ids that no batch points at, which reads as
                // "production progress reset". Same shape as phase-0/06;
                // refuse instead of silently orphaning.
                if ($order->items()->whereHas('productionBatchItems')->exists()) {
                    throw new \DomainException(
                        'Buyurtma qatorlari ishlab chiqarish partiyasiga bog\'langan. Mahsulot ro\'yxatini o\'zgartirib bo\'lmaydi.'
                    );
                }

                $order->items()->delete();
                $this->syncItems($order, $data['items'], $userId);
            }

            return $order->fresh()->load(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge']);
        });
    }

    /**
     * Delete an order and its items.
     */
    /**
     * Closes an order that was delivered outside the system, without a
     * shipment.
     *
     * Shipments were not recorded in the ERP between August and October 2026
     * (the scanner never worked on prod), so many orders that physically left
     * still read "on production" with every carpet unshipped. Left open they
     * keep showing in the production list and — worse — the scanner keeps
     * offering their lines, so a new carpet for that client lands on an order
     * that was delivered months ago.
     *
     * Status becomes 'shipped', which every "still open" query already
     * excludes (production list, stock-for-active-orders, the shipment scan
     * and wizards). Reservations are released: a delivered order claims no
     * stock. Deliberately NOT touched: stock movements (nothing is known about
     * what left the warehouse, and inventing OUT movements would make the
     * ledger lie in the other direction), production batches, and the order
     * lines themselves. The note and the audit log record who did it and why;
     * the existing status edit can reopen it.
     */
    public function markDelivered(Order $order, int $userId, ?string $reason = null): Order
    {
        $closable = [
            Order::STATUS_PENDING,
            Order::STATUS_PLANNED,
            Order::STATUS_ON_PRODUCTION,
            Order::STATUS_DONE,
        ];

        if (! in_array($order->status, $closable, true)) {
            throw new \DomainException(
                "Bu buyurtma \"{$order->status}\" holatida — uni yetkazildi deb belgilab bo'lmaydi."
            );
        }

        return DB::transaction(function () use ($order, $userId, $reason): Order {
            $order = Order::whereKey($order->id)->lockForUpdate()->firstOrFail();

            $user = \App\Models\User::find($userId);
            $line = sprintf(
                "[%s] %s tomonidan yetkazildi deb belgilandi (yuk xatisiz).%s",
                now()->format('d.m.Y H:i'),
                $user?->name ?? "#{$userId}",
                $reason !== null && trim($reason) !== '' ? ' Sabab: ' . trim($reason) : '',
            );

            $order->update([
                'status' => Order::STATUS_SHIPPED,
                'notes'  => trim(($order->notes ? $order->notes . "\n" : '') . $line),
            ]);

            $this->reservationService->releaseForOrder($order, 'order_marked_delivered');

            \Illuminate\Support\Facades\Log::info('order.marked_delivered', [
                'order_id' => $order->id,
                'user_id'  => $userId,
                'reason'   => $reason,
            ]);

            return $order->fresh();
        });
    }

    public function delete(Order $order): void
    {
        DB::transaction(function () use ($order): void {
            // Same guard as update(): production_batch_items.source_order_item_id
            // is nullOnDelete, so deleting the order items here would silently
            // sever the link to any batch already produced against them (the
            // batch item survives, orphaned, and its source_type goes stale —
            // reads later as if it were never linked to a client order).
            if ($order->items()->whereHas('productionBatchItems')->exists()) {
                throw new \DomainException(
                    'Buyurtma qatorlari ishlab chiqarish partiyasiga bog\'langan. Buyurtmani o\'chirib bo\'lmaydi.'
                );
            }

            $order->items()->delete();
            $order->delete();
        });
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function syncItems(Order $order, array $items, int $userId): void
    {
        foreach ($items as $itemData) {
            $variant = $this->variantService->findOrCreate(
                $itemData['product_color_id'],
                $itemData['product_size_id'] ?? null,
                $itemData['product_edge_id'] ?? null,
            );

            $orderItem = $order->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
            ]);

            // Reserve unconditionally, even if it pushes `available` negative
            // — an order for carpets that don't exist yet is the business,
            // not an error. See
            // instructions/phase-3/07-stock-reservations.md.
            $this->reservationService->reserveForOrderItem($orderItem, $userId);
        }
    }
}
