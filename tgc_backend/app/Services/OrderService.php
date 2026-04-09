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
                return $existing->load(['user', 'client', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);
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

            return $order->load(['user', 'client', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);
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
                $order->items()->delete();
                $this->syncItems($order, $data['items']);
            }

            return $order->fresh()->load(['user', 'client', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);
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
            );

            $order->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
            ]);
        }
    }
}
