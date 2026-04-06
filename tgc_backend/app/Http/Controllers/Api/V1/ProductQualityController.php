<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductQualityResource;
use App\Models\ProductQuality;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class ProductQualityController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return ProductQualityResource::collection(
            ProductQuality::orderBy('quality_name')->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'quality_name' => ['required', 'string', 'max:100', Rule::unique('product_qualities', 'quality_name')],
            'density'      => ['nullable', 'integer', 'min:1'],
        ]);

        $quality = ProductQuality::create($data);

        return response()->json(['data' => new ProductQualityResource($quality)], 201);
    }

    public function update(Request $request, ProductQuality $productQuality): JsonResponse
    {
        $data = $request->validate([
            'quality_name' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('product_qualities', 'quality_name')->ignore($productQuality->id)],
            'density'      => ['nullable', 'integer', 'min:1'],
        ]);

        $productQuality->update($data);

        return response()->json(['data' => new ProductQualityResource($productQuality)]);
    }

    public function destroy(ProductQuality $productQuality): JsonResponse
    {
        $productQuality->delete();

        return response()->json(['message' => 'Product quality deleted successfully.']);
    }
}
