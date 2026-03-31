<?php

namespace App\Services;

use App\Models\Product;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleService
{
    /**
     * Create a sale with items and corresponding outgoing stock movements.
     * Supports idempotent creation via external_uuid.
     */
    public function create(array $data, int $userId): Sale
    {
        // Idempotent: return existing sale if external_uuid already stored
        if (! empty($data['external_uuid'])) {
            $existing = Sale::where('external_uuid', $data['external_uuid'])->first();
            if ($existing) {
                return $existing->load(['client', 'user', 'items.product']);
            }
        }

        return DB::transaction(function () use ($data, $userId): Sale {
            $this->assertSufficientStock($data['items']);

            $total = $this->calculateTotal($data['items']);

            $sale = Sale::create([
                'external_uuid'  => $data['external_uuid'] ?? null,
                'client_id'      => $data['client_id'],
                'user_id'        => $userId,
                'sale_date'      => $data['sale_date'],
                'total_amount'   => $total,
                'payment_status' => $data['payment_status'] ?? Sale::PAYMENT_PENDING,
                'notes'          => $data['notes'] ?? null,
            ]);

            $this->syncItems($sale, $data['items'], $userId);

            return $sale->load(['client', 'user', 'items.product']);
        });
    }

    /**
     * Update header fields and optionally replace all items.
     */
    public function update(Sale $sale, array $data, int $userId): Sale
    {
        return DB::transaction(function () use ($sale, $data, $userId): Sale {
            if (! empty($data['items'])) {
                $this->assertSufficientStock($data['items']);
                $this->reverseMovements($sale, $userId);
                $sale->items()->delete();

                $itemsToPersist = $data['items'];
            }

            $sale->update(array_filter([
                'client_id'      => $data['client_id']      ?? null,
                'sale_date'      => $data['sale_date']       ?? null,
                'payment_status' => $data['payment_status']  ?? null,
                'notes'          => array_key_exists('notes', $data) ? $data['notes'] : null,
                'total_amount'   => isset($itemsToPersist) ? $this->calculateTotal($itemsToPersist) : null,
            ], fn ($v) => $v !== null));

            if (isset($itemsToPersist)) {
                $this->syncItems($sale->fresh(), $itemsToPersist, $userId);
            }

            return $sale->fresh()->load(['client', 'user', 'items.product']);
        });
    }

    /**
     * Delete a sale and reverse its stock movements.
     */
    public function delete(Sale $sale, int $userId): void
    {
        DB::transaction(function () use ($sale, $userId): void {
            $this->reverseMovements($sale, $userId);
            $sale->items()->delete();
            $sale->delete();
        });
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function syncItems(Sale $sale, array $items, int $userId): void
    {
        $doc = WarehouseDocument::create([
            'type'          => WarehouseDocument::TYPE_OUT,
            'client_id'     => $sale->client_id,
            'user_id'       => $userId,
            'document_date' => $sale->sale_date,
            'notes'         => "Auto: Sale #{$sale->id}",
        ]);

        foreach ($items as $itemData) {
            $subtotal = round((float) $itemData['price'] * $itemData['quantity'], 2);

            $sale->items()->create([
                'product_id' => $itemData['product_id'],
                'quantity'   => $itemData['quantity'],
                'price'      => $itemData['price'],
                'subtotal'   => $subtotal,
            ]);

            $doc->items()->create([
                'product_id' => $itemData['product_id'],
                'quantity'   => $itemData['quantity'],
                'notes'      => "Sale #{$sale->id}",
            ]);

            StockMovement::create([
                'product_id'            => $itemData['product_id'],
                'warehouse_document_id' => $doc->id,
                'sale_id'               => $sale->id,
                'client_id'             => $sale->client_id,
                'user_id'               => $userId,
                'movement_type'         => WarehouseDocument::TYPE_OUT,
                'quantity'              => $itemData['quantity'],
                'movement_date'         => $sale->sale_date,
                'notes'                 => "Sale #{$sale->id}",
            ]);
        }
    }

    private function reverseMovements(Sale $sale, int $userId): void
    {
        $doc = WarehouseDocument::create([
            'type'          => WarehouseDocument::TYPE_RETURN,
            'client_id'     => $sale->client_id,
            'user_id'       => $userId,
            'document_date' => now(),
            'notes'         => "Auto: Reversal of Sale #{$sale->id}",
        ]);

        foreach ($sale->items as $item) {
            $doc->items()->create([
                'product_id' => $item->product_id,
                'quantity'   => $item->quantity,
                'notes'      => "Reversal of Sale #{$sale->id}",
            ]);

            StockMovement::create([
                'product_id'            => $item->product_id,
                'warehouse_document_id' => $doc->id,
                'sale_id'               => $sale->id,
                'client_id'             => $sale->client_id,
                'user_id'               => $userId,
                'movement_type'         => WarehouseDocument::TYPE_RETURN,
                'quantity'              => $item->quantity,
                'movement_date'         => now(),
                'notes'                 => "Reversal of Sale #{$sale->id}",
            ]);
        }
    }

    private function assertSufficientStock(array $items): void
    {
        $errors = [];

        foreach ($items as $index => $itemData) {
            $product      = Product::findOrFail($itemData['product_id']);
            $currentStock = $this->getStock($product->id);

            if ($currentStock < $itemData['quantity']) {
                $errors["items.{$index}.quantity"] = [
                    "Insufficient stock for product '{$product->name}'. Available: {$currentStock}, Requested: {$itemData['quantity']}.",
                ];
            }
        }

        if (! empty($errors)) {
            throw ValidationException::withMessages($errors);
        }
    }

    private function calculateTotal(array $items): float
    {
        return array_sum(array_map(
            fn ($i) => round((float) $i['price'] * $i['quantity'], 2),
            $items,
        ));
    }

    private function getStock(int $productId): int
    {
        $in = StockMovement::where('product_id', $productId)
            ->whereIn('movement_type', [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN])
            ->sum('quantity');

        $out = StockMovement::where('product_id', $productId)
            ->where('movement_type', WarehouseDocument::TYPE_OUT)
            ->sum('quantity');

        return (int) ($in - $out);
    }
}
