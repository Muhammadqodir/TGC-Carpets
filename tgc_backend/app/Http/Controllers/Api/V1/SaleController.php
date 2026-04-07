<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Sale\StoreSaleRequest;
use App\Http\Requests\Sale\UpdateSaleRequest;
use App\Http\Resources\SaleResource;
use App\Models\Sale;
use App\Services\SaleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class SaleController extends Controller
{
    public function __construct(private readonly SaleService $service) {}

    public function index(Request $request): AnonymousResourceCollection
    {
        $sales = Sale::with(['client', 'user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize'])
            ->when($request->filled('client_id'),      fn ($q) => $q->where('client_id', $request->client_id))
            ->when($request->filled('user_id'),        fn ($q) => $q->where('user_id', $request->user_id))
            ->when($request->filled('date_from'),      fn ($q) => $q->whereDate('sale_date', '>=', $request->date_from))
            ->when($request->filled('date_to'),        fn ($q) => $q->whereDate('sale_date', '<=', $request->date_to))
            ->latest('sale_date')
            ->paginate($request->integer('per_page', 20));

        return SaleResource::collection($sales);
    }

    public function store(StoreSaleRequest $request): JsonResponse
    {
        $sale = $this->service->create($request->validated(), $request->user()->id);

        $statusCode = $sale->wasRecentlyCreated ? 201 : 200;

        return response()->json(['data' => new SaleResource($sale)], $statusCode);
    }

    public function show(Sale $sale): JsonResponse
    {
        $sale->load(['client', 'user', 'items.variant.productColor.product', 'items.variant.productColor.color', 'items.variant.productSize']);

        return response()->json(['data' => new SaleResource($sale)]);
    }

    public function update(UpdateSaleRequest $request, Sale $sale): JsonResponse
    {
        $sale = $this->service->update($sale, $request->validated(), $request->user()->id);

        return response()->json(['data' => new SaleResource($sale)]);
    }

    public function destroy(Request $request, Sale $sale): JsonResponse
    {
        $this->service->delete($sale, $request->user()->id);

        return response()->json(['message' => 'Sale deleted and stock movements reversed.']);
    }
}
