<?php

namespace App\Services;

use App\Models\DefectDocument;
use App\Models\DefectDocumentItem;
use App\Models\DefectDocumentPhoto;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use App\Models\ProductionEvent;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

/**
 * Defects and scrap, modelled as events — see
 * instructions/phase-2/05-defect-and-scrap-as-events.md.
 *
 * A defect document line can consume two different things:
 *  - the unproduced remainder of a batch item (a carpet came off the loom
 *    faulty, never labelled) — a single 'defect' event, +n
 *  - already-produced, not-yet-warehoused units (QC condemns a finished,
 *    counted-good carpet) — a 'scrap' event (-n, moves produced_quantity
 *    down) PLUS a 'defect' event (+n), because produced_quantity and
 *    defect_quantity are two different caches and each event type feeds
 *    exactly one of them (see ProductionEvent's mapping).
 *
 * The remainder is always consumed first.
 */
class DefectDocumentService
{
    public function create(ProductionBatch $productionBatch, array $data, array $photos, int $userId): DefectDocument
    {
        return DB::transaction(function () use ($productionBatch, $data, $photos, $userId): DefectDocument {
            $document = DefectDocument::create([
                'production_batch_id' => $productionBatch->id,
                'user_id'             => $userId,
                'datetime'            => $data['datetime'] ?? now(),
                'description'         => $data['description'] ?? null,
            ]);

            foreach ($data['items'] ?? [] as $itemData) {
                $this->recordDefectItem(
                    $document,
                    (int) $itemData['production_batch_item_id'],
                    (int) $itemData['quantity'],
                    $userId,
                );
            }

            foreach ($photos as $photo) {
                $path = $photo->store('defect-documents', 'public');
                DefectDocumentPhoto::create([
                    'defect_document_id' => $document->id,
                    'path'               => $path,
                ]);
            }

            $this->checkAndCompleteProductionBatch($productionBatch);

            return $document;
        });
    }

    private function recordDefectItem(DefectDocument $document, int $batchItemId, int $qty, int $userId): void
    {
        $item = ProductionBatchItem::lockForUpdate()->find($batchItemId);

        if (! $item) {
            throw ValidationException::withMessages([
                'items' => ["Partiya mahsuloti #{$batchItemId} topilmadi."],
            ]);
        }

        // Consume the unproduced remainder first; only then condemn produced
        // units — most defects found on a partially-labelled batch are among
        // what hasn't come off the loom yet.
        $unproducedRemainder = max(0, $item->planned_quantity - $item->produced_quantity - $item->defect_quantity);
        $fromRemainder = min($qty, $unproducedRemainder);
        $fromProduced  = $qty - $fromRemainder;

        // Boundary: once a unit has been received into the warehouse it is
        // stock, not a production correction — condemning it there is a
        // warehouse write-off, out of scope here.
        if ($fromProduced > 0 && ($item->produced_quantity - $item->warehouse_received_quantity) < $fromProduced) {
            throw ValidationException::withMessages([
                'items' => [
                    "Mahsulot #{$item->id}: {$fromProduced} dona allaqachon omborga qabul qilingan. "
                    . 'Iltimos, ombordan hisobdan chiqarish hujjatini rasmiylashtiring.',
                ],
            ]);
        }

        DefectDocumentItem::create([
            'defect_document_id'       => $document->id,
            'production_batch_item_id' => $item->id,
            'quantity'                 => $qty,
        ]);

        ProductionEvent::create([
            'production_batch_item_id' => $item->id,
            'event_type'               => ProductionEvent::TYPE_DEFECT,
            'quantity'                 => $qty,
            'occurred_at'              => $document->datetime,
            'user_id'                  => $userId,
            'defect_document_id'       => $document->id,
            'reason'                   => $document->description,
            'created_at'               => now(),
        ]);
        $item->increment('defect_quantity', $qty);

        if ($fromProduced > 0) {
            ProductionEvent::create([
                'production_batch_item_id' => $item->id,
                'event_type'               => ProductionEvent::TYPE_SCRAP,
                'quantity'                 => -$fromProduced,
                'occurred_at'              => $document->datetime,
                'user_id'                  => $userId,
                'defect_document_id'       => $document->id,
                'reason'                   => $document->description,
                'created_at'               => now(),
            ]);
            $item->decrement('produced_quantity', $fromProduced);
        }
    }

    /**
     * Reverse a defect document instead of leaking (PROD-2). Appends
     * reversing 'defect'/'scrap' events and corrects the counters — the
     * original events are never mutated or deleted, only offset. Must read
     * the document's items before delete() runs, since
     * defect_document_items cascade-deletes with the document.
     */
    public function delete(DefectDocument $defectDocument, int $userId): void
    {
        DB::transaction(function () use ($defectDocument, $userId): void {
            $items = $defectDocument->items()->get();

            foreach ($items as $docItem) {
                $item = ProductionBatchItem::lockForUpdate()->find($docItem->production_batch_item_id);

                if (! $item) {
                    continue;   // item hard-deleted elsewhere; nothing to reverse
                }

                $qty = (int) $docItem->quantity;

                // How much of this document's defect on this item was a
                // scrap of produced units? Needed to reverse both events, not
                // just the defect one.
                $scrapped = (int) ProductionEvent::where('production_batch_item_id', $item->id)
                    ->where('defect_document_id', $defectDocument->id)
                    ->where('event_type', ProductionEvent::TYPE_SCRAP)
                    ->sum('quantity');   // negative or zero

                ProductionEvent::create([
                    'production_batch_item_id' => $item->id,
                    'event_type'               => ProductionEvent::TYPE_DEFECT,
                    'quantity'                 => -$qty,          // reversing entry
                    'occurred_at'              => now(),          // the reversal happens NOW
                    'user_id'                  => $userId,
                    'reason'                   => "Reversal of defect document #{$defectDocument->id}",
                    'created_at'               => now(),
                ]);

                $decremented = ProductionBatchItem::where('id', $item->id)
                    ->where('defect_quantity', '>=', $qty)
                    ->decrement('defect_quantity', $qty);

                if (! $decremented) {
                    Log::warning('defect_quantity decrement skipped — counter already below document quantity', [
                        'production_batch_item_id' => $item->id,
                        'document_id'               => $defectDocument->id,
                        'quantity'                  => $qty,
                    ]);
                }

                if ($scrapped < 0) {
                    ProductionEvent::create([
                        'production_batch_item_id' => $item->id,
                        'event_type'               => ProductionEvent::TYPE_SCRAP,
                        'quantity'                 => -$scrapped,   // positive: undo the scrap
                        'occurred_at'              => now(),
                        'user_id'                  => $userId,
                        'reason'                   => "Reversal of defect document #{$defectDocument->id}",
                        'created_at'               => now(),
                    ]);
                    $item->increment('produced_quantity', -$scrapped);
                }
            }

            foreach ($defectDocument->photos as $photo) {
                Storage::disk('public')->delete($photo->path);
            }

            // Batch does not auto-reopen on delete — that is a workflow
            // decision with downstream consequences (warehouse receipts,
            // order status), left to phase-3/03 (batch state machine).
            $defectDocument->delete();
        });
    }

    /**
     * Check if all items in the batch are processed and update status to completed.
     */
    private function checkAndCompleteProductionBatch(ProductionBatch $productionBatch): void
    {
        if ($productionBatch->status !== ProductionBatch::STATUS_IN_PROGRESS) {
            return;
        }

        $items = ProductionBatchItem::where('production_batch_id', $productionBatch->id)->get();

        $allProcessed = $items->every(function ($item) {
            $produced = $item->produced_quantity ?? 0;
            $defect = $item->defect_quantity ?? 0;
            return ($produced + $defect) >= $item->planned_quantity;
        });

        if ($allProcessed) {
            $productionBatch->update([
                'status'             => ProductionBatch::STATUS_COMPLETED,
                'completed_datetime' => now(),
            ]);
        }
    }
}
