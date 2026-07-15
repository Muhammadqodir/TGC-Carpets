<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Production\StoreDefectDocumentRequest;
use App\Http\Resources\DefectDocumentResource;
use App\Models\DefectDocument;
use App\Models\ProductionBatch;
use App\Services\DefectDocumentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class DefectDocumentController extends Controller
{
    public function __construct(private readonly DefectDocumentService $service) {}

    /**
     * GET /production-batches/{productionBatch}/defect-documents
     */
    public function index(Request $request, ProductionBatch $productionBatch): AnonymousResourceCollection
    {
        $documents = DefectDocument::with(['user', 'items.productionBatchItem.variant.productColor.product', 'items.productionBatchItem.variant.productColor.color', 'items.productionBatchItem.variant.productSize', 'items.productionBatchItem.variant.productEdge', 'photos'])
            ->where('production_batch_id', $productionBatch->id)
            ->latest('datetime')
            ->paginate($this->perPage($request));

        return DefectDocumentResource::collection($documents);
    }

    /**
     * POST /production-batches/{productionBatch}/defect-documents
     */
    public function store(
        StoreDefectDocumentRequest $request,
        ProductionBatch $productionBatch,
    ): JsonResponse {
        $document = $this->service->create(
            $productionBatch,
            [
                'datetime'    => $request->input('datetime'),
                'description' => $request->input('description'),
                'items'       => $request->input('items', []),
            ],
            $request->hasFile('photos') ? $request->file('photos') : [],
            $request->user()->id,
        );

        $document->load(['user', 'items.productionBatchItem.variant.productColor.product', 'items.productionBatchItem.variant.productColor.color', 'items.productionBatchItem.variant.productSize', 'items.productionBatchItem.variant.productEdge', 'photos']);

        return response()->json(['data' => new DefectDocumentResource($document)], 201);
    }

    /**
     * GET /defect-documents/{defectDocument}
     */
    public function show(DefectDocument $defectDocument): JsonResponse
    {
        $defectDocument->load(['user', 'productionBatch', 'items.productionBatchItem.variant.productColor.product', 'items.productionBatchItem.variant.productColor.color', 'items.productionBatchItem.variant.productSize', 'items.productionBatchItem.variant.productEdge', 'photos']);

        return response()->json(['data' => new DefectDocumentResource($defectDocument)]);
    }

    /**
     * DELETE /defect-documents/{defectDocument}
     */
    public function destroy(Request $request, DefectDocument $defectDocument): JsonResponse
    {
        $this->service->delete($defectDocument, $request->user()->id);

        return response()->json(['message' => 'Nuxson hujjati o\'chirildi.']);
    }
}
