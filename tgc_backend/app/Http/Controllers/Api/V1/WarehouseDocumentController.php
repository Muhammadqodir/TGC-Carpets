<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\WarehouseDocument\StoreWarehouseDocumentRequest;
use App\Http\Requests\WarehouseDocument\UpdateWarehouseDocumentRequest;
use App\Http\Resources\WarehouseDocumentPhotoResource;
use App\Http\Resources\WarehouseDocumentResource;
use App\Models\WarehouseDocument;
use App\Services\WarehouseDocumentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class WarehouseDocumentController extends Controller
{
    public function __construct(private readonly WarehouseDocumentService $service) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $documents = WarehouseDocument::with(['user', 'client', 'items.product', 'items.productSize', 'photos'])
            ->when($request->filled('type'),      fn ($q) => $q->where('type', $request->type))
            ->when($request->filled('client_id'), fn ($q) => $q->where('client_id', $request->client_id))
            ->when($request->filled('user_id'),   fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('date_from'), fn ($q) => $q->whereDate('document_date', '>=', $request->date_from))
            ->when($request->filled('date_to'),   fn ($q) => $q->whereDate('document_date', '<=', $request->date_to))
            ->latest('document_date')
            ->paginate($request->integer('per_page', 20));

        return WarehouseDocumentResource::collection($documents);
    }

    public function store(StoreWarehouseDocumentRequest $request): JsonResponse
    {
        $document = $this->service->create($request->validated(), $request->user()->id);

        $statusCode = $document->wasRecentlyCreated ? 201 : 200;

        return response()->json(['data' => new WarehouseDocumentResource($document)], $statusCode);
    }

    public function show(WarehouseDocument $warehouseDocument): JsonResponse
    {
        $warehouseDocument->load(['user', 'client', 'items.product', 'items.productSize', 'photos']);

        return response()->json(['data' => new WarehouseDocumentResource($warehouseDocument)]);
    }

    public function update(UpdateWarehouseDocumentRequest $request, WarehouseDocument $warehouseDocument): JsonResponse
    {
        $document = $this->service->update($warehouseDocument, $request->validated(), $request->user()->id);

        return response()->json(['data' => new WarehouseDocumentResource($document)]);
    }

    public function destroy(Request $request, WarehouseDocument $warehouseDocument): JsonResponse
    {
        $this->service->delete($warehouseDocument, $request->user()->id);

        return response()->json(['message' => 'Document deleted and stock movements reversed.']);
    }

    // ── PDF ───────────────────────────────────────────────────────────────────

    public function uploadPdf(Request $request, WarehouseDocument $warehouseDocument): JsonResponse
    {
        $request->validate([
            'pdf' => ['required', 'file', 'mimes:pdf', 'max:20480'],
        ]);

        $path = $request->file('pdf')->storeAs(
            'warehouse-documents/pdfs',
            "doc_{$warehouseDocument->id}_{$warehouseDocument->uuid}.pdf",
            'public'
        );

        $warehouseDocument->update(['pdf_path' => $path]);

        return response()->json([
            'pdf_url' => asset('storage/' . $path),
        ]);
    }

    // ── Photos ────────────────────────────────────────────────────────────────

    public function uploadPhoto(Request $request, WarehouseDocument $warehouseDocument): JsonResponse
    {
        $request->validate([
            'photo' => ['required', 'file', 'image', 'max:10240'],
        ]);

        $photo = $this->service->attachPhoto($warehouseDocument, $request->file('photo'));

        return response()->json(['data' => new WarehouseDocumentPhotoResource($photo)], 201);
    }

    public function deletePhoto(WarehouseDocument $warehouseDocument, int $photoId): JsonResponse
    {
        $this->service->deletePhoto($warehouseDocument, $photoId);

        return response()->json(['message' => 'Photo deleted.']);
    }
}
