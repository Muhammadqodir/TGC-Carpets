<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductColor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ProductColorController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = ProductColor::with(['color', 'product'])
            ->when($request->filled('product_id'), fn ($q) => $q->where('product_id', $request->product_id))
            ->when($request->filled('color_id'),   fn ($q) => $q->where('color_id', $request->color_id))
            ->latest()
            ->paginate($request->integer('per_page', 50));

        return response()->json([
            'data' => $query->map(fn ($pc) => [
                'id'        => $pc->id,
                'product'   => [
                    'id'   => $pc->product->id,
                    'name' => $pc->product->name,
                ],
                'color'     => [
                    'id'   => $pc->color->id,
                    'name' => $pc->color->name,
                ],
                'image_url' => $pc->image ? Storage::disk('public')->url($pc->image) : null,
                'created_at' => $pc->created_at?->toISOString(),
            ]),
            'meta' => [
                'current_page' => $query->currentPage(),
                'last_page'    => $query->lastPage(),
                'per_page'     => $query->perPage(),
                'total'        => $query->total(),
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id' => ['required', 'integer', 'exists:products,id'],
            'color_id'   => ['required', 'integer', 'exists:colors,id'],
            'image'      => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ]);

        $data = collect($validated)->except('image')->toArray();

        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store('products', 'public');
        }

        $pc = ProductColor::create($data);
        $pc->load(['color', 'product']);

        return response()->json([
            'data' => [
                'id'        => $pc->id,
                'product'   => ['id' => $pc->product->id, 'name' => $pc->product->name],
                'color'     => ['id' => $pc->color->id, 'name' => $pc->color->name],
                'image_url' => $pc->image ? Storage::disk('public')->url($pc->image) : null,
            ],
        ], 201);
    }

    public function update(Request $request, ProductColor $productColor): JsonResponse
    {
        $validated = $request->validate([
            'color_id' => ['sometimes', 'integer', 'exists:colors,id'],
            'image'    => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ]);

        $data = collect($validated)->except('image')->toArray();

        if ($request->hasFile('image')) {
            if ($productColor->image) {
                Storage::disk('public')->delete($productColor->image);
            }
            $data['image'] = $request->file('image')->store('products', 'public');
        }

        $productColor->update($data);
        $productColor->load(['color', 'product']);

        return response()->json([
            'data' => [
                'id'        => $productColor->id,
                'product'   => ['id' => $productColor->product->id, 'name' => $productColor->product->name],
                'color'     => ['id' => $productColor->color->id, 'name' => $productColor->color->name],
                'image_url' => $productColor->image ? Storage::disk('public')->url($productColor->image) : null,
            ],
        ]);
    }

    public function destroy(ProductColor $productColor): JsonResponse
    {
        if ($productColor->image) {
            Storage::disk('public')->delete($productColor->image);
        }

        $productColor->delete();

        return response()->json(['message' => 'Product color deleted.']);
    }
}
