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
        if ($hidden = ProductType::onlyTrashed()->where('type', $request->input('type'))->first()) {
            return $this->restoreHidden($request, $hidden);
        }

        $validated = $request->validate([
            'type'         => ['required', 'string', 'max:100', Rule::unique('product_types', 'type')],
            'is_printable' => ['sometimes', 'boolean'],
        ]);

        $productType = ProductType::create($validated);

        return response()->json(['data' => new ProductTypeResource($productType)], 201);
    }

    /** Adding a name that was hidden brings the old row back, links intact. */
    private function restoreHidden(Request $request, ProductType $productType): JsonResponse
    {
        $validated = $request->validate(['is_printable' => ['sometimes', 'boolean']]);

        $productType->restore();
        $productType->update($validated);

        return response()->json(['data' => new ProductTypeResource($productType)]);
    }

    public function update(Request $request, ProductType $productType): JsonResponse
    {
        $validated = $request->validate([
            'type'         => ['required', 'string', 'max:100', Rule::unique('product_types', 'type')->ignore($productType->id)],
            'is_printable' => ['sometimes', 'boolean'],
        ]);

        $productType->update($validated);

        return response()->json(['data' => new ProductTypeResource($productType)]);
    }

    public function usage(ProductType $productType): JsonResponse
    {
        return response()->json(['count' => $productType->products()->count()]);
    }

    public function archive(ProductType $productType): JsonResponse
    {
        $productType->update(['status' => ProductType::STATUS_ARCHIVED]);

        Product::where('product_type_id', $productType->id)
            ->where('status', Product::STATUS_ACTIVE)
            ->update(['status' => Product::STATUS_ARCHIVED]);

        return response()->json(['data' => new ProductTypeResource($productType)]);
    }

    public function unarchive(ProductType $productType): JsonResponse
    {
        $productType->update(['status' => ProductType::STATUS_ACTIVE]);

        Product::where('product_type_id', $productType->id)
            ->where('status', Product::STATUS_ARCHIVED)
            ->update(['status' => Product::STATUS_ACTIVE]);

        return response()->json(['data' => new ProductTypeResource($productType)]);
    }

    public function destroy(Request $request, ProductType $productType): JsonResponse
    {
        // mode=hide: soft-delete. It drops out of the pickers and lists, but
        // every product / variant / order that uses it keeps it unchanged.
        // Re-creating the same name later brings it back (see store()).
        if ($request->input('mode') === 'hide') {
            $productType->delete();

            return response()->json(['message' => 'Product type hidden.']);
        }

        $usageCount = $productType->products()->count();

        if ($usageCount > 0) {
            $request->validate([
                'replace_with_id' => ['required', 'integer', Rule::exists('product_types', 'id')],
            ]);

            Product::where('product_type_id', $productType->id)
                ->update(['product_type_id' => $request->replace_with_id]);
        }

        $productType->forceDelete();

        return response()->json(['message' => 'Product type deleted successfully.']);
    }
}
