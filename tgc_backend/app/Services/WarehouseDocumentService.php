<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductEdge;
use App\Models\ProductionBatchItem;
use App\Models\ProductVariant;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use App\Models\WarehouseDocumentPhoto;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\ValidationException;

class WarehouseDocumentService
{
    public function __construct(
        private readonly ProductVariantService $variantService,
        private readonly WarehousePdfService $pdfService,
    ) {}

    /**
     * Create a warehouse document with items and stock movements inside a single transaction.
     * Supports idempotent creation via external_uuid.
     */
    public function create(array $data, int $userId): WarehouseDocument
    {
        if (! empty($data['external_uuid'])) {
            $existing = WarehouseDocument::where('external_uuid', $data['external_uuid'])->first();
            if ($existing) {
                return $existing->load(['user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge', 'photos']);
            }
        }

        return DB::transaction(function () use ($data, $userId): WarehouseDocument {
            if ($data['type'] === WarehouseDocument::TYPE_OUT) {
                $this->assertSufficientStock($data['items']);
            }

            $document = WarehouseDocument::create([
                'external_uuid' => $data['external_uuid'] ?? null,
                'type'          => $data['type'],
                'user_id'       => $userId,
                'document_date' => $data['document_date'],
                'notes'         => $data['notes'] ?? null,
            ]);

            $this->syncItems($document, $data['items'], $userId);
            $this->checkAndAutoCompleteOrders($document->fresh());

            // Generate and store PDF
            $pdfPath = $this->pdfService->generatePdf($document);
            $document->update(['pdf_path' => $pdfPath]);

            return $document->load(['user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge', 'photos']);
        });
    }

    /**
     * Update header fields and optionally replace all items.
     */
    public function update(WarehouseDocument $document, array $data, int $userId): WarehouseDocument
    {
        return DB::transaction(function () use ($document, $data, $userId): WarehouseDocument {
            $document->update(array_filter([
                'type'          => $data['type']          ?? $document->type,
                'document_date' => $data['document_date'] ?? $document->document_date,
                'notes'         => array_key_exists('notes', $data) ? $data['notes'] : $document->notes,
            ], fn ($v) => $v !== null));

            if (isset($data['items'])) {
                $effectiveType = $document->fresh()->type;

                if ($effectiveType === WarehouseDocument::TYPE_OUT) {
                    $this->assertSufficientStock($data['items']);
                }

                $this->reverseMovements($document, $userId);
                $document->items()->delete();

                $this->syncItems($document->fresh(), $data['items'], $userId);
            }

            $this->checkAndAutoCompleteOrders($document->fresh());

            // Regenerate PDF
            $freshDocument = $document->fresh();
            $pdfPath = $this->pdfService->generatePdf($freshDocument);
            $freshDocument->update(['pdf_path' => $pdfPath]);

            return $freshDocument->load(['user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize', 'items.variant.productEdge', 'photos']);
        });
    }

    /**
     * Delete a document and reverse all its stock movements.
     */
    public function delete(WarehouseDocument $document, int $userId): void
    {
        DB::transaction(function () use ($document, $userId): void {
            $this->reverseMovements($document, $userId);
            $document->items()->delete();
            $document->photos()->each(fn ($p) => $this->deletePhotoFile($p));
            $document->photos()->delete();
            $document->delete();
        });
    }

    /**
     * Attach a photo to a warehouse document.
     */
    public function attachPhoto(WarehouseDocument $document, UploadedFile $file): WarehouseDocumentPhoto
    {
        $path = $file->store("warehouse_documents/{$document->id}", 'public');

        return $document->photos()->create(['path' => $path]);
    }

    /**
     * Remove a single photo by ID from a document.
     */
    public function deletePhoto(WarehouseDocument $document, int $photoId): void
    {
        $photo = $document->photos()->findOrFail($photoId);
        $this->deletePhotoFile($photo);
        $photo->delete();
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private function syncItems(WarehouseDocument $document, array $items, int $userId): void
    {
        foreach ($items as $itemData) {
            $variant = $this->variantService->findOrCreate(
                $itemData['product_color_id'],
                $itemData['product_size_id'] ?? null,
                $itemData['product_edge_id'] ?? $this->defaultEdgeId(),
            );

            $item = $document->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
                'source_type'        => $itemData['source_type'] ?? null,
                'source_id'          => $itemData['source_id'] ?? null,
                'notes'              => $itemData['notes'] ?? null,
            ]);

            // Map warehouse document types to stock movement types
            // 'in' → 'in' (stock coming into warehouse)
            // 'out' → 'out' (stock leaving warehouse)
            // 'return' → 'in' (returned items add back to stock)
            // 'adjustment' → 'in' (inventory corrections typically add stock)
            $movementType = match ($document->type) {
                WarehouseDocument::TYPE_IN,
                WarehouseDocument::TYPE_RETURN,
                WarehouseDocument::TYPE_ADJUSTMENT => StockMovement::TYPE_IN,
                WarehouseDocument::TYPE_OUT        => StockMovement::TYPE_OUT,
            };

            StockMovement::create([
                'product_variant_id'         => $variant->id,
                'warehouse_document_item_id' => $item->id,
                'user_id'                    => $userId,
                'movement_type'              => $movementType,
                'quantity'                   => $itemData['quantity'],
                'movement_date'              => $document->document_date,
                'notes'                      => $document->notes,
            ]);

            if ($document->type === WarehouseDocument::TYPE_IN) {
                $this->creditProductionBatchItems($variant->id, (int) $itemData['quantity']);
            }
        }
    }

    /**
     * Reverse the stock movements already recorded for this document's items.
     *
     * The direction of the reversal is derived from the ledger rows themselves
     * (net of everything already recorded for the item), NOT from
     * $document->type — that column may have been mutated by update() since
     * the movements were written, which would reverse in the wrong direction.
     * Summing to a net figure and writing one compensating movement is
     * naturally idempotent: call this twice and the second call writes nothing.
     */
    private function reverseMovements(WarehouseDocument $document, int $userId): void
    {
        foreach ($document->items as $item) {
            $net = (int) $item->stockMovements()
                ->selectRaw("COALESCE(SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE -quantity END), 0) as net")
                ->value('net');

            if ($net === 0) {
                continue;
            }

            StockMovement::create([
                'product_variant_id'         => $item->product_variant_id,
                'warehouse_document_item_id' => $item->id,
                'user_id'                    => $userId,
                'movement_type'              => $net > 0 ? StockMovement::TYPE_OUT : StockMovement::TYPE_IN,
                'quantity'                   => abs($net),
                'movement_date'              => $document->document_date,
                'notes'                      => "Reversal of document #{$document->id}",
            ]);

            if ($net > 0) {
                $this->debitProductionBatchItems($item->product_variant_id, abs($net));
            }
        }
    }

    private function assertSufficientStock(array $items): void
    {
        $errors = [];

        foreach ($items as $index => $itemData) {
            $productColorId = $itemData['product_color_id'];
            $sizeId         = $itemData['product_size_id'] ?? null;
            $edgeId         = $itemData['product_edge_id'] ?? $this->defaultEdgeId();

            // Mirrors findOrCreate()'s resolution exactly (color, size, edge) so
            // the check and the write in syncItems() can never resolve to
            // different variants.
            $variant = ProductVariant::where('product_color_id', $productColorId)
                ->when(
                    $sizeId !== null,
                    fn ($q) => $q->where('product_size_id', $sizeId),
                    fn ($q) => $q->whereNull('product_size_id'),
                )
                ->when(
                    $edgeId !== null,
                    fn ($q) => $q->where('product_edge_id', $edgeId),
                    fn ($q) => $q->whereNull('product_edge_id'),
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

    /**
     * The client does not send product_edge_id on warehouse documents
     * (verified: tgc_client's WarehouseDocumentItemEntity has no edge field).
     * Every existing variant was backfilled to the 'R' edge
     * (2026_06_07_000002), so defaulting here — rather than to null/whereNull,
     * which matches nothing post-backfill — is what stops findOrCreate() from
     * minting a duplicate NULL-edge variant per document. See
     * instructions/phase-1/04-pass-product-edge-id-warehouse.md.
     */
    private function defaultEdgeId(): ?int
    {
        return ProductEdge::where('code', 'R')->value('id');
    }

    private function getStock(int $variantId): int
    {
        $base = StockMovement::where('product_variant_id', $variantId);

        $in  = (clone $base)
            ->where('movement_type', StockMovement::TYPE_IN)
            ->sum('quantity');

        $out = (clone $base)
            ->where('movement_type', StockMovement::TYPE_OUT)
            ->sum('quantity');

        return (int) ($in - $out);
    }

    /**
     * FIFO: distribute received quantity across production batch items for a variant.
     * Targets batches with produced items that haven't been received yet.
     * Includes cancelled batches because produced items still exist physically.
     *
     * Throws if the warehouse is receiving more than production recorded —
     * accepting the stock movement and silently dropping the unallocated
     * remainder is worse than rejecting the document. See
     * instructions/phase-1/07-symmetric-fifo-allocation.md.
     */
    private function creditProductionBatchItems(int $variantId, int $quantity): void
    {
        if ($quantity <= 0) {
            return;
        }

        $batchItems = ProductionBatchItem::where('product_variant_id', $variantId)
            ->whereRaw('(COALESCE(produced_quantity, 0) - COALESCE(warehouse_received_quantity, 0)) > 0')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        $remaining = $quantity;
        foreach ($batchItems as $batchItem) {
            if ($remaining <= 0) {
                break;
            }
            $receivable = $batchItem->produced_quantity - $batchItem->warehouse_received_quantity;
            $credit     = min($remaining, $receivable);
            $batchItem->increment('warehouse_received_quantity', $credit);
            $remaining -= $credit;
        }

        if ($remaining > 0) {
            $this->reportAllocationShortfall(sprintf(
                'Cannot allocate %d of %d received units for variant %d: production batch items '
                . 'only account for %d unreceived units. The warehouse is receiving more than '
                . 'production recorded.',
                $remaining, $quantity, $variantId, $quantity - $remaining
            ), $variantId, 'credit');
        }
    }

    /**
     * FIFO: undo previously credited warehouse_received_quantity (used on reversal).
     *
     * Must walk the same order as creditProductionBatchItems, or a reversal
     * debits a different batch item than the one the original credit filled.
     */
    private function debitProductionBatchItems(int $variantId, int $quantity): void
    {
        if ($quantity <= 0) {
            return;
        }

        $batchItems = ProductionBatchItem::where('product_variant_id', $variantId)
            ->where('warehouse_received_quantity', '>', 0)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        $remaining = $quantity;
        foreach ($batchItems as $batchItem) {
            if ($remaining <= 0) {
                break;
            }
            $debit = min($remaining, $batchItem->warehouse_received_quantity);
            $batchItem->decrement('warehouse_received_quantity', $debit);
            $remaining -= $debit;
        }

        if ($remaining > 0) {
            $this->reportAllocationShortfall(sprintf(
                'Cannot debit %d of %d units for variant %d: production batch items only hold '
                . '%d received units. The reversal exceeds what was credited.',
                $remaining, $quantity, $variantId, $quantity - $remaining
            ), $variantId, 'debit');
        }
    }

    /**
     * Gated behind config('warehouse.enforce_allocation_check') — log-only
     * until the reconciliation query in reconcile-before-deploy.sql has been
     * run against production and the mismatch rate is understood. If the
     * warehouse routinely receives more than production recorded, this is
     * normal operating procedure, not a rare fault, and throwing blind would
     * stop the goods-in desk. See
     * instructions/phase-1/07-symmetric-fifo-allocation.md "Rollback".
     */
    private function reportAllocationShortfall(string $message, int $variantId, string $direction): void
    {
        if (! config('warehouse.enforce_allocation_check', false)) {
            Log::warning('warehouse.allocation.would_reject', [
                'variant_id' => $variantId,
                'direction'  => $direction,
                'message'    => $message,
            ]);

            return;   // remainder stays silently dropped, exactly as before
        }

        throw ValidationException::withMessages(['items' => [$message]]);
    }

    /**
     * After a TYPE_IN document is saved, check every affected order and mark it
     * as 'done' if all its items have been fully received into the warehouse.
     *
     * Fulfillment = SUM(production_batch_items.warehouse_received_quantity)
     *               >= order_item.quantity  for every item on the order.
     */
    private function checkAndAutoCompleteOrders(WarehouseDocument $document): void
    {
        if ($document->type !== WarehouseDocument::TYPE_IN) {
            return;
        }

        $variantIds = $document->items()->pluck('product_variant_id');

        if ($variantIds->isEmpty()) {
            return;
        }

        // Find all orders that have at least one item tied to these variants via production batches
        $orderIds = OrderItem::whereHas('productionBatchItems', function ($q) use ($variantIds): void {
            $q->whereIn('product_variant_id', $variantIds);
        })->pluck('order_id')->unique();

        if ($orderIds->isEmpty()) {
            return;
        }

        $eligibleOrders = Order::whereIn('id', $orderIds)
            ->whereNotIn('status', [
                Order::STATUS_DONE,
                Order::STATUS_SHIPPED,
                Order::STATUS_CANCELED,
            ])
            ->with('items.productionBatchItems')
            ->get();

        foreach ($eligibleOrders as $order) {
            // An order is fulfilled when every order_item has enough warehouse_received_quantity
            // Sum ALL productionBatchItems (including from cancelled batches) because
            // physical items exist regardless of batch status.
            $allFulfilled = $order->items->every(function (OrderItem $orderItem): bool {
                // Explicitly load all production batch items without filters
                $received = ProductionBatchItem::where('source_order_item_id', $orderItem->id)
                    ->sum('warehouse_received_quantity');

                return $received >= $orderItem->quantity;
            });

            if ($allFulfilled) {
                $order->update(['status' => Order::STATUS_DONE]);
            }
        }
    }

    private function deletePhotoFile(WarehouseDocumentPhoto $photo): void
    {
        if (\Illuminate\Support\Facades\Storage::disk('public')->exists($photo->path)) {
            \Illuminate\Support\Facades\Storage::disk('public')->delete($photo->path);
        }
    }
}

