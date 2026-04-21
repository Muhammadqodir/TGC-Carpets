<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\RawMaterial\StoreBatchMovementRequest;
use App\Http\Requests\RawMaterial\StoreRawMaterialRequest;
use App\Http\Requests\RawMaterial\UpdateRawMaterialRequest;
use App\Http\Resources\RawMaterialResource;
use App\Http\Resources\RawMaterialStockMovementResource;
use App\Models\RawMaterial;
use App\Models\RawMaterialStockMovement;
use App\Services\RawMaterialStockService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class RawMaterialController extends Controller
{
    public function __construct(private readonly RawMaterialStockService $stockService) {}

    // ── Raw Materials CRUD ────────────────────────────────────────────────────

    /**
     * GET /api/v1/raw-materials
     *
     * Returns paginated list with current stock quantity.
     * Supports ?type=... filter.
     */
    public function index(Request $request): JsonResponse
    {
        $stockSub = DB::table('raw_material_stock_movements as sm')
            ->selectRaw(
                'COALESCE(SUM(CASE WHEN sm.type = ? THEN sm.quantity ELSE -sm.quantity END), 0)',
                [RawMaterialStockMovement::TYPE_RECEIVED]
            )
            ->whereColumn('sm.material_id', 'raw_materials.id');

        $materials = RawMaterial::query()
            ->when($request->filled('type'), fn ($q) => $q->where('type', $request->type))
            ->when(
                $request->filled('search'),
                fn ($q) => $q->where('name', 'like', '%' . $request->search . '%')
            )
            ->selectRaw('raw_materials.*')
            ->selectSub($stockSub, 'stock_quantity')
            ->orderBy('type')
            ->orderBy('name')
            ->paginate($request->integer('per_page', 50));

        return response()->json([
            'data' => RawMaterialResource::collection($materials),
            'meta' => [
                'current_page' => $materials->currentPage(),
                'last_page'    => $materials->lastPage(),
                'per_page'     => $materials->perPage(),
                'total'        => $materials->total(),
            ],
        ]);
    }

    /**
     * POST /api/v1/raw-materials
     */
    public function store(StoreRawMaterialRequest $request): JsonResponse
    {
        $material = RawMaterial::create($request->validated());

        return response()->json(['data' => new RawMaterialResource($material)], 201);
    }

    /**
     * GET /api/v1/raw-materials/{rawMaterial}
     */
    public function show(RawMaterial $rawMaterial): JsonResponse
    {
        $rawMaterial->stock_quantity = (float) (
            DB::table('raw_material_stock_movements as sm')
                ->selectRaw(
                    'COALESCE(SUM(CASE WHEN sm.type = ? THEN sm.quantity ELSE -sm.quantity END), 0) as qty',
                    [RawMaterialStockMovement::TYPE_RECEIVED]
                )
                ->where('sm.material_id', $rawMaterial->id)
                ->value('qty') ?? 0
        );

        return response()->json(['data' => new RawMaterialResource($rawMaterial)]);
    }

    /**
     * PATCH /api/v1/raw-materials/{rawMaterial}
     */
    public function update(UpdateRawMaterialRequest $request, RawMaterial $rawMaterial): JsonResponse
    {
        $rawMaterial->update($request->validated());

        return response()->json(['data' => new RawMaterialResource($rawMaterial->fresh())]);
    }

    /**
     * DELETE /api/v1/raw-materials/{rawMaterial}
     */
    public function destroy(RawMaterial $rawMaterial): JsonResponse
    {
        $rawMaterial->delete();

        return response()->json(['message' => 'Raw material deleted.']);
    }

    // ── Stock movements ───────────────────────────────────────────────────────

    /**
     * GET /api/v1/raw-materials/movements
     *
     * Returns paginated stock movements, filterable by material_id and type.
     */
    public function movements(Request $request): AnonymousResourceCollection
    {
        $movements = RawMaterialStockMovement::with(['material', 'user'])
            ->when($request->filled('material_id'), fn ($q) => $q->where('material_id', $request->material_id))
            ->when($request->filled('type'),        fn ($q) => $q->where('type', $request->type))
            ->when($request->filled('date_from'),   fn ($q) => $q->whereDate('date_time', '>=', $request->date_from))
            ->when($request->filled('date_to'),     fn ($q) => $q->whereDate('date_time', '<=', $request->date_to))
            ->latest('date_time')
            ->paginate($request->integer('per_page', 30));

        return RawMaterialStockMovementResource::collection($movements);
    }

    /**
     * POST /api/v1/raw-materials/movements/batch
     *
     * Creates multiple stock movements in a single transaction.
     */
    public function storeBatchMovement(StoreBatchMovementRequest $request): JsonResponse
    {
        $movements = $this->stockService->storeBatch(
            $request->validated(),
            $request->user()->id,
        );

        return response()->json([
            'data' => RawMaterialStockMovementResource::collection($movements),
        ], 201);
    }
}
