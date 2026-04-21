<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ColorResource;
use App\Models\Color;
use App\Models\ProductColor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
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
            'name' => ['required', 'string', 'max:100', Rule::unique('colors', 'name')],
        ]);

        $color = Color::create($validated);

        return response()->json(['data' => new ColorResource($color)], 201);
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
            $request->validate([
                'replace_with_id' => ['required', 'integer', Rule::exists('colors', 'id')],
            ]);

            ProductColor::where('color_id', $color->id)
                ->update(['color_id' => $request->replace_with_id]);
        }

        $color->delete();

        return response()->json(['message' => 'Color deleted successfully.']);
    }
}
