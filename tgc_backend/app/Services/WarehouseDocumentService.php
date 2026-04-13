<?php

namespace App\Services;

use App\Models\ProductionBatchItem;
use App\Models\ProductVariant;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use App\Models\WarehouseDocumentPhoto;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
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
                return $existing->load(['user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize', 'photos']);
            }
        }

        return DB::transaction(function () use ($data, $userId): WarehouseDocument {
            if ($data['type'] === WarehouseDocument::TYPE_OUT) {
                $this->assertSufficientStock($data['items']);
            }

            $document = WarehouseDocument::create([
                'external_uuid' => $data['external_uuid'] ?? null,
                'type'          => $data['type'],
                'source_type'   => $data['source_type'] ?? null,
                'source_id'     => $data['source_id']   ?? null,
                'user_id'       => $userId,
                'document_date' => $data['document_date'],
                'notes'         => $data['notes'] ?? null,
            ]);

            $this->syncItems($document, $data['items'], $userId);

            // Generate and store PDF
            $pdfPath = $this->pdfService->generatePdf($document);
            $document->update(['pdf_path' => $pdfPath]);

            return $document->load(['user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize', 'photos']);
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
                'source_type'   => array_key_exists('source_type', $data) ? $data['source_type'] : $document->source_type,
                'source_id'     => array_key_exists('source_id', $data)   ? $data['source_id']   : $document->source_id,
                'document_date' => $data['document_date'] ?? $document->document_date,
                'notes'         => array_key_exists('notes', $data) ? $data['notes'] : $document->notes,
            ], fn ($v) => $v !== null));

            if (! empty($data['items'])) {
                $effectiveType = $document->fresh()->type;

                if ($effectiveType === WarehouseDocument::TYPE_OUT) {
                    $this->assertSufficientStock($data['items']);
                }

                $this->reverseMovements($document, $userId);
                $document->items()->delete();

                $this->syncItems($document->fresh(), $data['items'], $userId);
            }

            // Regenerate PDF
            $freshDocument = $document->fresh();
            $pdfPath = $this->pdfService->generatePdf($freshDocument);
            $freshDocument->update(['pdf_path' => $pdfPath]);

            return $freshDocument->load(['user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize', 'photos']);
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
            );

            $document->items()->create([
                'product_variant_id' => $variant->id,
                'quantity'           => $itemData['quantity'],
                'notes'              => $itemData['notes'] ?? null,
            ]);

            StockMovement::create([
                'product_variant_id'    => $variant->id,
                'warehouse_document_id' => $document->id,
                'source_type'           => $document->source_type,
                'source_id'             => $document->source_id,
                'user_id'               => $userId,
                'movement_type'         => $document->type,
                'quantity'              => $itemData['quantity'],
                'movement_date'         => $document->document_date,
                'notes'                 => $document->notes,
            ]);

            if ($document->type === WarehouseDocument::TYPE_IN) {
                $this->creditProductionBatchItems($variant->id, (int) $itemData['quantity']);
            }
        }
    }

    private function reverseMovements(WarehouseDocument $document, int $userId): void
    {
        $reverseType = match ($document->type) {
            WarehouseDocument::TYPE_IN         => WarehouseDocument::TYPE_OUT,
            WarehouseDocument::TYPE_OUT        => WarehouseDocument::TYPE_IN,
            WarehouseDocument::TYPE_RETURN     => WarehouseDocument::TYPE_OUT,
            WarehouseDocument::TYPE_ADJUSTMENT => WarehouseDocument::TYPE_ADJUSTMENT,
        };

        foreach ($document->items as $item) {
            StockMovement::create([
                'product_variant_id'    => $item->product_variant_id,
                'warehouse_document_id' => $document->id,
                'source_type'           => $document->source_type,
                'source_id'             => $document->source_id,
                'user_id'               => $userId,
                'movement_type'         => $reverseType,
                'quantity'              => $item->quantity,
                'movement_date'         => now(),
                'notes'                 => "Reversal of document #{$document->id}",
            ]);

            if ($document->type === WarehouseDocument::TYPE_IN) {
                $this->debitProductionBatchItems($item->product_variant_id, (int) $item->quantity);
            }
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

    /**
     * FIFO: distribute received quantity across production batch items for a variant.
     * Only targets completed/in_progress batches that still have unaccounted produced goods.
     */
    private function creditProductionBatchItems(int $variantId, int $quantity): void
    {
        if ($quantity <= 0) {
            return;
        }

        $batchItems = ProductionBatchItem::where('product_variant_id', $variantId)
            ->whereHas('productionBatch', fn ($q) => $q->whereIn('status', ['completed', 'in_progress']))
            ->whereRaw('(produced_quantity - defect_quantity - warehouse_received_quantity) > 0')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        $remaining = $quantity;
        foreach ($batchItems as $batchItem) {
            if ($remaining <= 0) {
                break;
            }
            $receivable = $batchItem->produced_quantity - $batchItem->defect_quantity - $batchItem->warehouse_received_quantity;
            $credit     = min($remaining, $receivable);
            $batchItem->increment('warehouse_received_quantity', $credit);
            $remaining -= $credit;
        }
    }

    /**
     * LIFO: undo previously credited warehouse_received_quantity (used on reversal).
     */
    private function debitProductionBatchItems(int $variantId, int $quantity): void
    {
        if ($quantity <= 0) {
            return;
        }

        $batchItems = ProductionBatchItem::where('product_variant_id', $variantId)
            ->where('warehouse_received_quantity', '>', 0)
            ->orderByDesc('id')
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
    }

    private function deletePhotoFile(WarehouseDocumentPhoto $photo): void
    {
        if (\Illuminate\Support\Facades\Storage::disk('public')->exists($photo->path)) {
            \Illuminate\Support\Facades\Storage::disk('public')->delete($photo->path);
        }
    }
}

