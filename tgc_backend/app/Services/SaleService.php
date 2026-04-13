<?php

namespace App\Services;

use App\Models\ProductVariant;
use App\Models\Sale;
use App\Models\SaleItem;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SaleService
{
    public function __construct(
        private readonly ProductVariantService $variantService,
    ) {}

    /**
     * Create a sale with items and corresponding outgoing stock movements.
     * Supports idempotent creation via external_uuid.
     */
    public function create(array $data, int $userId): Sale
    {
        if (! empty($data['external_uuid'])) {
            $existing = Sale::where('external_uuid', $data['external_uuid'])->first();
            if ($existing) {
                return $existing->load(['client', 'user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);
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
                'notes'          => $data['notes'] ?? null,
            ]);

            $this->syncItems($sale, $data['items'], $userId);

            return $sale->load(['client', 'user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);
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
                'notes'          => array_key_exists('notes', $data) ? $data['notes'] : null,
                'total_amount'   => isset($itemsToPersist) ? $this->calculateTotal($itemsToPersist) : null,
            ], fn ($v) => $v !== null));

            if (isset($itemsToPersist)) {
                $this->syncItems($sale->fresh(), $itemsToPersist, $userId);
            }

            return $sale->fresh()->load(['client', 'user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);
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
            'source_type'   => 'sale',
            'source_id'     => $sale->id,
            'user_id'       => $userId,
            'document_date' => $sale->sale_date,
            'notes'         => "Auto: Sale #{$sale->id}",
        ]);

        foreach ($items as $itemData) {
            $variant  = $this->variantService->findOrCreate(
                $itemData['product_color_id'],
                $itemData['product_size_id'] ?? null,
            );
            $subtotal = round((float) $itemData['price'] * $itemData['quantity'], 2);

            $sale->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
                'price'              => $itemData['price'],
                'subtotal'           => $subtotal,
            ]);

            $doc->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
                'notes'              => "Sale #{$sale->id}",
            ]);

            StockMovement::create([
                'product_variant_id'    => $variant->id,
                'warehouse_document_id' => $doc->id,
                'source_type'           => 'sale',
                'source_id'             => $sale->id,
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
            'source_type'   => 'sale',
            'source_id'     => $sale->id,
            'user_id'       => $userId,
            'document_date' => now(),
            'notes'         => "Auto: Reversal of Sale #{$sale->id}",
        ]);

        foreach ($sale->items as $item) {
            $doc->items()->create([
                'product_variant_id' => $item->product_variant_id,
                'quantity'           => $item->quantity,
                'notes'              => "Reversal of Sale #{$sale->id}",
            ]);

            StockMovement::create([
                'product_variant_id'    => $item->product_variant_id,
                'warehouse_document_id' => $doc->id,
                'source_type'           => 'sale',
                'source_id'             => $sale->id,
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
            $productColorId = $itemData['product_color_id'];
            $sizeId         = $itemData['product_size_id'] ?? null;

            $variant = ProductVariant::where('product_color_id', $productColorId)
                ->when(
                    $sizeId !== null,
                    fn ($q) => $q->where('product_size_id', $sizeId),
                    fn ($q) => $q->whereNull('product_size_id'),
                )
                ->first();

            $currentStock = $variant ? $this->getStock($variant->id) : 0;

            if ($currentStock < $itemData['quantity']) {
                $pc = \App\Models\ProductColor::with('product', 'color')->find($productColorId);
                $productName = $pc?->product?->name ?? "Product color #{$productColorId}";
                $colorName   = $pc?->color?->name   ?? '';
                $sizeLabel   = $sizeId ? " (size #{$sizeId})" : '';

                $errors["items.{$index}.quantity"] = [
                    "Insufficient stock for '{$productName} ({$colorName})'{$sizeLabel}. Available: {$currentStock}, Requested: {$itemData['quantity']}.",
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

    private function getStock(int $variantId): int
    {
        $base = StockMovement::where('product_variant_id', $variantId);

        $in  = (clone $base)
            ->whereIn('movement_type', [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN])
            ->sum('quantity');

        $out = (clone $base)
            ->where('movement_type', WarehouseDocument::TYPE_OUT)
            ->sum('quantity');

        return (int) ($in - $out);
    }
}

