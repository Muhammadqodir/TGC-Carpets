<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ColorResource;
use App\Models\Color;
use App\Models\ProductColor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ColorController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $colors = Color::query()
            ->when($request->filled('search'), fn ($q) => $q->where('name', 'like', '%'.$request->search.'%'))
            ->orderBy('name')
            ->get();

        return ColorResource::collection($colors);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100'],
        ]);

        $color = Color::firstOrCreate(['name' => $validated['name']]);

        return response()->json(
            ['data' => new ColorResource($color)],
            $color->wasRecentlyCreated ? 201 : 200
        );
    }

    public function update(Request $request, Color $color): JsonResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:100', Rule::unique('colors', 'name')->ignore($color->id)],
        ]);

        $color->update($validated);

        return response()->json(['data' => new ColorResource($color)]);
    }

    public function usage(Color $color): JsonResponse
    {
        return response()->json(['count' => $color->productColors()->count()]);
    }

    public function destroy(Request $request, Color $color): JsonResponse
    {
        $usageCount = $color->productColors()->count();

        if ($usageCount > 0) {
            $validated = $request->validate([
                'replace_with_id' => [
                    'required',
                    'integer',
                    Rule::exists('colors', 'id'),
                    Rule::notIn([$color->id]),
                ],
            ]);

            DB::transaction(function () use ($color, $validated) {
                ProductColor::where('color_id', $color->id)
                    ->get()
                    ->each(function (ProductColor $productColor) use ($validated) {
                        $duplicate = ProductColor::where('product_id', $productColor->product_id)
                            ->where('color_id', $validated['replace_with_id'])
                            ->exists();

                        if ($duplicate) {
                            // Product already has the replacement color; drop the
                            // now-redundant row instead of colliding on the unique key.
                            $productColor->delete();
                        } else {
                            $productColor->update(['color_id' => $validated['replace_with_id']]);
                        }
                    });
            });
        }

        $color->delete();

        return response()->json(['message' => 'Color deleted successfully.']);
    }
}
