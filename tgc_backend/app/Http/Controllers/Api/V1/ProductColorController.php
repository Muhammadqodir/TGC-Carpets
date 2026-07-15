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
            ->paginate($this->perPage($request));

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

        // Return the existing record without creating a duplicate.
        $existing = ProductColor::where('product_id', $validated['product_id'])
            ->where('color_id', $validated['color_id'])
            ->first();

        if ($existing) {
            $existing->load(['color', 'product']);
            return response()->json([
                'data' => [
                    'id'        => $existing->id,
                    'product'   => ['id' => $existing->product->id, 'name' => $existing->product->name],
                    'color'     => ['id' => $existing->color->id, 'name' => $existing->color->name],
                    'image_url' => $existing->image ? Storage::disk('public')->url($existing->image) : null,
                ],
            ], 200);
        }

        $data = [
            'product_id' => $validated['product_id'],
            'color_id'   => $validated['color_id'],
        ];

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

        if (isset($validated['color_id']) && $validated['color_id'] !== $productColor->color_id) {
            $duplicate = ProductColor::where('product_id', $productColor->product_id)
                ->where('color_id', $validated['color_id'])
                ->where('id', '!=', $productColor->id)
                ->exists();

            if ($duplicate) {
                return response()->json([
                    'message' => 'This product already has that color assigned.',
                    'errors' => ['color_id' => ['This product already has that color assigned.']],
                ], 422);
            }
        }

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
