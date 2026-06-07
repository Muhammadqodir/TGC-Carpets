<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductEdgeResource;
use App\Models\ProductEdge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class ProductEdgeController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return ProductEdgeResource::collection(
            ProductEdge::orderBy('title')->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code'  => ['required', 'string', 'max:10', Rule::unique('product_edges', 'code')],
            'title' => ['required', 'string', 'max:100', Rule::unique('product_edges', 'title')],
        ]);

        $edge = ProductEdge::create($data);

        return response()->json(['data' => new ProductEdgeResource($edge)], 201);
    }

    public function update(Request $request, ProductEdge $productEdge): JsonResponse
    {
        $data = $request->validate([
            'code'  => ['sometimes', 'required', 'string', 'max:10', Rule::unique('product_edges', 'code')->ignore($productEdge->id)],
            'title' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('product_edges', 'title')->ignore($productEdge->id)],
        ]);

        $productEdge->update($data);

        return response()->json(['data' => new ProductEdgeResource($productEdge)]);
    }

    public function usage(ProductEdge $productEdge): JsonResponse
    {
        return response()->json(['count' => $productEdge->productVariants()->count()]);
    }

    public function destroy(Request $request, ProductEdge $productEdge): JsonResponse
    {
        $usageCount = $productEdge->productVariants()->count();

        if ($usageCount > 0) {
            $request->validate([
                'replace_with_id' => ['required', 'integer', Rule::exists('product_edges', 'id')],
            ]);

            $productEdge->productVariants()->update(['product_edge_id' => $request->replace_with_id]);
        }

        $productEdge->delete();

        return response()->json(['message' => 'Product edge deleted successfully.']);
    }
}
