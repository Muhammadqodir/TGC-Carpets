<?php

namespace App\Services;

use App\Models\Order;
use Illuminate\Support\Facades\DB;

class OrderService
{
    public function __construct(
        private readonly ProductVariantService $variantService,
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

            $this->syncItems($order, $data['items']);

            return $order->load(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge']);
        });
    }

    /**
     * Update order header fields and optionally replace all items.
     */
    public function update(Order $order, array $data): Order
    {
        return DB::transaction(function () use ($order, $data): Order {
            $order->update(array_filter([
                'client_id'  => array_key_exists('client_id', $data) ? $data['client_id'] : null,
                'status'     => $data['status']     ?? null,
                'order_date' => $data['order_date'] ?? null,
                'notes'      => array_key_exists('notes', $data) ? $data['notes'] : null,
            ], fn ($v) => $v !== null));

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
                $this->syncItems($order, $data['items']);
            }

            return $order->fresh()->load(['user', 'client', 'items.variant.productColor.product.productType', 'items.variant.productColor.product.productQuality', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge']);
        });
    }

    /**
     * Delete an order and its items.
     */
    public function delete(Order $order): void
    {
        DB::transaction(function () use ($order): void {
            $order->items()->delete();
            $order->delete();
        });
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function syncItems(Order $order, array $items): void
    {
        foreach ($items as $itemData) {
            $variant = $this->variantService->findOrCreate(
                $itemData['product_color_id'],
                $itemData['product_size_id'] ?? null,
                $itemData['product_edge_id'] ?? null,
            );

            $order->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
            ]);
        }
    }
}
