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
use Illuminate\Support\Facades\Storage;

class ProductController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $products = Product::query()
            ->select('products.*')
            ->selectSub($this->stockSubquery(), 'stock')
            ->when($request->filled('search'), fn ($q) => $q->where(function ($sub) use ($request) {
                $sub->where('name',     'like', '%'.$request->search.'%')
                    ->orWhere('sku_code', 'like', '%'.$request->search.'%');
            }))
            ->when($request->filled('sku_code'), fn ($q) => $q->where('sku_code', 'like', '%'.$request->sku_code.'%'))
            ->when($request->filled('name'),     fn ($q) => $q->where('name',     'like', '%'.$request->name.'%'))
            ->when($request->filled('quality'),  fn ($q) => $q->where('quality',  $request->quality))
            ->when($request->filled('color'),    fn ($q) => $q->where('color',    $request->color))
            ->when($request->filled('status'),   fn ($q) => $q->where('status',   $request->status))
            ->latest()
            ->paginate($request->integer('per_page', 20));

        return ProductResource::collection($products);
    }

    public function store(StoreProductRequest $request): JsonResponse
    {
        $data = collect($request->validated())->except('image')->toArray();

        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store('products', 'public');
        }

        $product = Product::create($data);
        $product->refresh();

        return response()->json(['data' => new ProductResource($product)], 201);
    }

    public function show(Product $product): JsonResponse
    {
        $product = Product::select('products.*')
            ->selectSub($this->stockSubquery(), 'stock')
            ->findOrFail($product->id);

        return response()->json(['data' => new ProductResource($product)]);
    }

    private function stockSubquery(): \Illuminate\Database\Query\Builder
    {
        return DB::table('stock_movements')
            ->selectRaw('COALESCE(SUM(CASE WHEN movement_type IN ("in", "return") THEN quantity ELSE -quantity END), 0)')
            ->whereColumn('stock_movements.product_id', 'products.id');
    }

    public function update(UpdateProductRequest $request, Product $product): JsonResponse
    {
        $data = collect($request->validated())->except('image')->toArray();

        if ($request->hasFile('image')) {
            if ($product->image) {
                Storage::disk('public')->delete($product->image);
            }
            $data['image'] = $request->file('image')->store('products', 'public');
        }

        $product->update($data);

        return response()->json(['data' => new ProductResource($product)]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();

        return response()->json(['message' => 'Product archived successfully.']);
    }
}
