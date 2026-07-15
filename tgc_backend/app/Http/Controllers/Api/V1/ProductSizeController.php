<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\ProductSize\StoreProductSizeRequest;
use App\Http\Requests\ProductSize\UpdateProductSizeRequest;
use App\Http\Resources\ProductSizeResource;
use App\Models\ProductSize;
use App\Models\ProductVariant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

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

    public function usage(ProductSize $productSize): JsonResponse
    {
        return response()->json(['count' => $productSize->variants()->count()]);
    }

    public function destroy(Request $request, ProductSize $productSize): JsonResponse
    {
        $usageCount = $productSize->variants()->count();

        if ($usageCount > 0) {
            $validated = $request->validate([
                'replace_with_id' => [
                    'required',
                    'integer',
                    Rule::exists('product_sizes', 'id'),
                    Rule::notIn([$productSize->id]),
                ],
            ]);

            $conflict = ProductVariant::where('product_size_id', $productSize->id)
                ->whereExists(function ($query) use ($validated) {
                    $query->selectRaw('1')
                        ->from('product_variants as pv2')
                        ->whereRaw('pv2.product_color_id <=> product_variants.product_color_id')
                        ->whereRaw('pv2.product_edge_id <=> product_variants.product_edge_id')
                        ->where('pv2.product_size_id', $validated['replace_with_id']);
                })
                ->first();

            if ($conflict) {
                return response()->json([
                    'message' => 'Cannot merge: some products already have a variant with the replacement size (e.g. variant #'.$conflict->id.'). Resolve the conflicting variant manually before deleting this size.',
                    'errors' => ['replace_with_id' => ['A conflicting variant already exists for the replacement size.']],
                ], 422);
            }

            ProductVariant::where('product_size_id', $productSize->id)
                ->update(['product_size_id' => $validated['replace_with_id']]);
        }

        $productSize->delete();

        return response()->json(['message' => 'Product size deleted successfully.']);
    }
}
