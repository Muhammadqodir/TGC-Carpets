<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductTypeResource;
use App\Models\Product;
use App\Models\ProductType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class ProductTypeController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return ProductTypeResource::collection(ProductType::orderBy('type')->get());
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'type' => ['required', 'string', 'max:100', Rule::unique('product_types', 'type')],
        ]);

        $productType = ProductType::create($validated);

        return response()->json(['data' => new ProductTypeResource($productType)], 201);
    }

    public function update(Request $request, ProductType $productType): JsonResponse
    {
        $validated = $request->validate([
            'type' => ['required', 'string', 'max:100', Rule::unique('product_types', 'type')->ignore($productType->id)],
        ]);

        $productType->update($validated);

        return response()->json(['data' => new ProductTypeResource($productType)]);
    }

    public function usage(ProductType $productType): JsonResponse
    {
        return response()->json(['count' => $productType->products()->count()]);
    }

    public function destroy(Request $request, ProductType $productType): JsonResponse
    {
        $usageCount = $productType->products()->count();

        if ($usageCount > 0) {
            $request->validate([
                'replace_with_id' => ['required', 'integer', Rule::exists('product_types', 'id')],
            ]);

            Product::where('product_type_id', $productType->id)
                ->update(['product_type_id' => $request->replace_with_id]);
        }

        $productType->delete();

        return response()->json(['message' => 'Product type deleted successfully.']);
    }
}
