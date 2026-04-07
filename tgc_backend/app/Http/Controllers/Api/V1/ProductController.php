<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Product\StoreProductRequest;
use App\Http\Requests\Product\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class ProductController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $products = Product::query()
            ->with(['productType', 'productQuality', 'productColors.color'])
            ->select('products.*')
            ->selectSub($this->stockSubquery(), 'stock')
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', '%'.$request->search.'%'))
            ->when($request->filled('name'),               fn ($q) => $q->where('name',     'like', '%'.$request->name.'%'))
            ->when($request->filled('product_quality_id'), fn ($q) => $q->where('product_quality_id', $request->product_quality_id))
            ->when($request->filled('status'),             fn ($q) => $q->where('status',   $request->status))
            ->when($request->filled('product_type_id'),    fn ($q) => $q->where('product_type_id', $request->product_type_id))
            ->orderByDesc('stock')
            ->paginate($request->integer('per_page', 20));

        return ProductResource::collection($products);
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        $product = Product::create($request->validated());
        $product->refresh();

        return response()->json(['data' => new ProductResource($product)], 201);
    }

    public function show(Product $product): JsonResponse
    {
        $product = Product::with(['productType', 'productQuality', 'productColors.color'])
            ->select('products.*')
            ->selectSub($this->stockSubquery(), 'stock')
            ->findOrFail($product->id);

        return response()->json(['data' => new ProductResource($product)]);
    }

    private function stockSubquery(): \Illuminate\Database\Query\Builder
    {
        return DB::table('stock_movements')
            ->join('product_variants', 'product_variants.id', '=', 'stock_movements.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->selectRaw('COALESCE(SUM(CASE WHEN movement_type IN ("in", "return") THEN quantity ELSE -quantity END), 0)')
            ->whereColumn('product_colors.product_id', 'products.id');
    }

    public function update(UpdateProductRequest $request, Product $product): JsonResponse
    {
        $product->update($request->validated());

        return response()->json(['data' => new ProductResource($product)]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return response()->json(['message' => 'Product archived successfully.']);
    }
}
