<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProductSize\StoreProductSizeRequest;
use App\Http\Requests\ProductSize\UpdateProductSizeRequest;
use App\Http\Resources\ProductSizeResource;
use App\Models\ProductSize;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProductSizeController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $sizes = ProductSize::with('productType')
            ->when(
                $request->filled('product_type_id'),
                fn ($q) => $q->where('product_type_id', $request->product_type_id),
            )
            ->orderBy('length')
            ->orderBy('width')
            ->get();

        return ProductSizeResource::collection($sizes);
    }

    public function store(StoreProductSizeRequest $request): JsonResponse
    {
        $size = ProductSize::create($request->validated());
        $size->load('productType');

        return response()->json(['data' => new ProductSizeResource($size)], 201);
    }

    public function show(ProductSize $productSize): JsonResponse
    {
        $productSize->load('productType');

        return response()->json(['data' => new ProductSizeResource($productSize)]);
    }

    public function update(UpdateProductSizeRequest $request, ProductSize $productSize): JsonResponse
    {
        $productSize->update($request->validated());
        $productSize->load('productType');

        return response()->json(['data' => new ProductSizeResource($productSize)]);
    }

    public function destroy(ProductSize $productSize): JsonResponse
    {
        $productSize->delete();

        return response()->json(['message' => 'Product size deleted successfully.']);
    }
}
