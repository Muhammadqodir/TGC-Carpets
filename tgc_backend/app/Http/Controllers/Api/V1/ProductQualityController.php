<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductQualityResource;
use App\Models\Product;
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

    public function usage(ProductQuality $productQuality): JsonResponse
    {
        return response()->json(['count' => $productQuality->products()->count()]);
    }

    public function destroy(Request $request, ProductQuality $productQuality): JsonResponse
    {
        $usageCount = $productQuality->products()->count();

        if ($usageCount > 0) {
            $request->validate([
                'replace_with_id' => ['required', 'integer', Rule::exists('product_qualities', 'id')],
            ]);

            Product::where('product_quality_id', $productQuality->id)
                ->update(['product_quality_id' => $request->replace_with_id]);
        }

        $productQuality->delete();

        return response()->json(['message' => 'Product quality deleted successfully.']);
    }
}
