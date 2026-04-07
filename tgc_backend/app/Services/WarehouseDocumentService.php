<?php

namespace App\Services;

use App\Models\Product;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use App\Models\WarehouseDocumentPhoto;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WarehouseDocumentService
{
    /**
     * Create a warehouse document with items and stock movements inside a single transaction.
     * Supports idempotent creation via external_uuid.
     */
    public function create(array $data, int $userId): WarehouseDocument
    {
        // Idempotent: return existing document if external_uuid is already stored
        if (! empty($data['external_uuid'])) {
            $existing = WarehouseDocument::where('external_uuid', $data['external_uuid'])->first();
            if ($existing) {
                return $existing->load(['user', 'client', 'items.product', 'photos']);
            }
        }

        return DB::transaction(function () use ($data, $userId): WarehouseDocument {
            // Validate stock availability for outgoing documents before any writes
            if ($data['type'] === WarehouseDocument::TYPE_OUT) {
                $this->assertSufficientStock($data['items']);
            }

            $document = WarehouseDocument::create([
                'external_uuid' => $data['external_uuid'] ?? null,
                'type'          => $data['type'],
                'client_id'     => $data['client_id'] ?? null,
                'user_id'       => $userId,
                'document_date' => $data['document_date'],
                'notes'         => $data['notes'] ?? null,
            ]);

            $this->syncItems($document, $data['items'], $userId);

            return $document->load(['user', 'client', 'items.product', 'photos']);
        });
    }

    /**
     * Update header fields and optionally replace all items.
     * If items are supplied the old items and associated movements are replaced.
     */
    public function update(WarehouseDocument $document, array $data, int $userId): WarehouseDocument
    {
        return DB::transaction(function () use ($document, $data, $userId): WarehouseDocument {
            $document->update(array_filter([
                'type'          => $data['type']          ?? $document->type,
                'client_id'     => array_key_exists('client_id', $data) ? $data['client_id'] : $document->client_id,
                'document_date' => $data['document_date'] ?? $document->document_date,
                'notes'         => array_key_exists('notes', $data) ? $data['notes'] : $document->notes,
            ], fn ($v) => $v !== null));

            if (! empty($data['items'])) {
                $effectiveType = $document->fresh()->type;

                if ($effectiveType === WarehouseDocument::TYPE_OUT) {
                    $this->assertSufficientStock($data['items']);
                }

                // Reverse old movements then delete old items
                $this->reverseMovements($document, $userId);
                $document->items()->delete();

                $this->syncItems($document->fresh(), $data['items'], $userId);
            }

            return $document->fresh()->load(['user', 'client', 'items.product', 'photos']);
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

    /**
     * Create document items and associated stock movements.
     */
    private function syncItems(WarehouseDocument $document, array $items, int $userId): void
    {
        foreach ($items as $itemData) {
            $document->items()->create([
                'product_id'      => $itemData['product_id'],
                'product_size_id' => $itemData['product_size_id'] ?? null,
                'quantity'        => $itemData['quantity'],
                'notes'           => $itemData['notes'] ?? null,
            ]);

            $this->createMovement($document, $itemData, $userId);
        }
    }

    /**
     * Write a stock_movement row for a single document item.
     */
    private function createMovement(WarehouseDocument $document, array $itemData, int $userId): void
    {
        StockMovement::create([
            'product_id'             => $itemData['product_id'],
            'product_size_id'        => $itemData['product_size_id'] ?? null,
            'warehouse_document_id'  => $document->id,
            'sale_id'                => null,
            'client_id'              => $document->client_id,
            'user_id'                => $userId,
            'movement_type'          => $document->type,
            'quantity'               => $itemData['quantity'],
            'movement_date'          => $document->document_date,
            'notes'                  => $document->notes,
        ]);
    }

    /**
     * Reverse all movements for a document by creating compensating entries.
     * We write compensating rows rather than deleting to preserve audit history.
     */
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
                'product_id'            => $item->product_id,
                'product_size_id'       => $item->product_size_id,
                'warehouse_document_id' => $document->id,
                'sale_id'               => null,
                'client_id'             => $document->client_id,
                'user_id'               => $userId,
                'movement_type'         => $reverseType,
                'quantity'              => $item->quantity,
                'movement_date'         => now(),
                'notes'                 => "Reversal of document #{$document->id}",
            ]);
        }
    }

    /**
     * Throw a validation exception if any product lacks sufficient stock.
     */
    private function assertSufficientStock(array $items): void
    {
        $errors = [];

        foreach ($items as $index => $itemData) {
            $product      = Product::findOrFail($itemData['product_id']);
            $sizeId       = $itemData['product_size_id'] ?? null;
            $currentStock = $this->getStock($product->id, $sizeId);

            if ($currentStock < $itemData['quantity']) {
                $sizeLabel = $sizeId ? " (size #{$sizeId})" : '';
                $errors["items.{$index}.quantity"] = [
                    "Insufficient stock for product '{$product->name}'{$sizeLabel}. Available: {$currentStock}, Requested: {$itemData['quantity']}.",
                ];
            }
        }

        if (! empty($errors)) {
            throw ValidationException::withMessages($errors);
        }
    }

    /**
     * Calculate current stock for a product (and optionally a specific size) from movement history.
     */
    private function getStock(int $productId, ?int $sizeId = null): int
    {
        $base = StockMovement::where('product_id', $productId)
            ->when($sizeId !== null, fn ($q) => $q->where('product_size_id', $sizeId));

        $in  = (clone $base)->whereIn('movement_type', [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN])->sum('quantity');
        $out = (clone $base)->where('movement_type', WarehouseDocument::TYPE_OUT)->sum('quantity');

        return (int) ($in - $out);
    }

    private function deletePhotoFile(WarehouseDocumentPhoto $photo): void
    {
        if (\Illuminate\Support\Facades\Storage::disk('public')->exists($photo->path)) {
            \Illuminate\Support\Facades\Storage::disk('public')->delete($photo->path);
        }
    }
}
