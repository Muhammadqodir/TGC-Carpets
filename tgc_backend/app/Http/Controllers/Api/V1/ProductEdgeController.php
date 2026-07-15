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
            $validated = $request->validate([
                'replace_with_id' => [
                    'required',
                    'integer',
                    Rule::exists('product_edges', 'id'),
                    Rule::notIn([$productEdge->id]),
                ],
            ]);

            $conflict = $productEdge->productVariants()
                ->whereExists(function ($query) use ($validated) {
                    $query->selectRaw('1')
                        ->from('product_variants as pv2')
                        ->whereRaw('pv2.product_color_id <=> product_variants.product_color_id')
                        ->whereRaw('pv2.product_size_id <=> product_variants.product_size_id')
                        ->where('pv2.product_edge_id', $validated['replace_with_id']);
                })
                ->first();

            if ($conflict) {
                return response()->json([
                    'message' => 'Cannot merge: some products already have a variant with the replacement edge (e.g. variant #'.$conflict->id.'). Resolve the conflicting variant manually before deleting this edge.',
                    'errors' => ['replace_with_id' => ['A conflicting variant already exists for the replacement edge.']],
                ], 422);
            }

            $productEdge->productVariants()->update(['product_edge_id' => $validated['replace_with_id']]);
        }

        $productEdge->delete();

        return response()->json(['message' => 'Product edge deleted successfully.']);
    }
}
