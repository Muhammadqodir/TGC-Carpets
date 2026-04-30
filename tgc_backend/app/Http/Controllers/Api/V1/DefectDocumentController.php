<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Production\StoreDefectDocumentRequest;
use App\Http\Resources\DefectDocumentResource;
use App\Models\DefectDocument;
use App\Models\DefectDocumentItem;
use App\Models\DefectDocumentPhoto;
use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class DefectDocumentController extends Controller
{
    /**
     * GET /production-batches/{productionBatch}/defect-documents
     */
    public function index(Request $request, ProductionBatch $productionBatch): AnonymousResourceCollection
    {
        $documents = DefectDocument::with(['user', 'items.productionBatchItem.variant.productColor.product', 'items.productionBatchItem.variant.productColor.color', 'items.productionBatchItem.variant.productSize', 'photos'])
            ->where('production_batch_id', $productionBatch->id)
            ->latest('datetime')
            ->paginate($request->integer('per_page', 20));

        return DefectDocumentResource::collection($documents);
    }

    /**
     * POST /production-batches/{productionBatch}/defect-documents
     */
    public function store(
        StoreDefectDocumentRequest $request,
        ProductionBatch $productionBatch,
    ): JsonResponse {
        $document = DB::transaction(function () use ($request, $productionBatch): DefectDocument {
            $document = DefectDocument::create([
                'production_batch_id' => $productionBatch->id,
                'user_id'             => $request->user()->id,
                'datetime'            => $request->input('datetime') ?? now(),
                'description'         => $request->input('description'),
            ]);

            foreach ($request->input('items', []) as $itemData) {
                DefectDocumentItem::create([
                    'defect_document_id'       => $document->id,
                    'production_batch_item_id' => $itemData['production_batch_item_id'],
                    'quantity'                 => $itemData['quantity'],
                ]);

                ProductionBatchItem::where('id', $itemData['production_batch_item_id'])
                    ->increment('defect_quantity', $itemData['quantity']);
            }

            if ($request->hasFile('photos')) {
                foreach ($request->file('photos') as $photo) {
                    $path = $photo->store('defect-documents', 'public');
                    DefectDocumentPhoto::create([
                        'defect_document_id' => $document->id,
                        'path'               => $path,
                    ]);
                }
            }

            // Check if all items are processed (produced + defect = planned)
            $this->checkAndCompleteProductionBatch($productionBatch);

            return $document;
        });

        $document->load(['user', 'items.productionBatchItem.variant.productColor.product', 'items.productionBatchItem.variant.productColor.color', 'items.productionBatchItem.variant.productSize', 'photos']);

        return response()->json(['data' => new DefectDocumentResource($document)], 201);
    }

    /**
     * GET /defect-documents/{defectDocument}
     */
    public function show(DefectDocument $defectDocument): JsonResponse
    {
        $defectDocument->load(['user', 'productionBatch', 'items.productionBatchItem.variant.productColor.product', 'items.productionBatchItem.variant.productColor.color', 'items.productionBatchItem.variant.productSize', 'photos']);

        return response()->json(['data' => new DefectDocumentResource($defectDocument)]);
    }

    /**
     * DELETE /defect-documents/{defectDocument}
     */
    public function destroy(DefectDocument $defectDocument): JsonResponse
    {
        DB::transaction(function () use ($defectDocument): void {
            // Delete stored photo files
            foreach ($defectDocument->photos as $photo) {
                Storage::disk('public')->delete($photo->path);
            }

            $defectDocument->delete();
        });

        return response()->json(['message' => 'Nuxson hujjati o\'chirildi.']);
    }

    /**
     * Check if all items in the batch are processed and update status to completed
     */
    private function checkAndCompleteProductionBatch(ProductionBatch $productionBatch): void
    {
        // Only check if batch is in_progress
        if ($productionBatch->status !== ProductionBatch::STATUS_IN_PROGRESS) {
            return;
        }

        // Get fresh data for all items in the batch
        $items = ProductionBatchItem::where('production_batch_id', $productionBatch->id)->get();

        // Check if all items are processed (produced + defect = planned)
        $allProcessed = $items->every(function ($item) {
            $produced = $item->produced_quantity ?? 0;
            $defect = $item->defect_quantity ?? 0;
            return ($produced + $defect) >= $item->planned_quantity;
        });

        // If all items are processed, mark the batch as completed
        if ($allProcessed) {
            $productionBatch->update([
                'status' => ProductionBatch::STATUS_COMPLETED,
                'completed_datetime' => now(),
            ]);
        }
    }
}
