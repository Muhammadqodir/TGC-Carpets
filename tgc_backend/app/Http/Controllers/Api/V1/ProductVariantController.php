<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductVariantResource;
use App\Models\ProductVariant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProductVariantController extends Controller
{
    /**
     * GET /api/v1/product-variants
     *
     * Paginated list of all known variants.
     * Filterable by product_id or exact barcode_value (useful for scanning).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $variants = ProductVariant::with(['productColor.product.productType', 'productColor.product.productQuality', 'productColor.color', 'productSize'])
            ->when($request->filled('product_color_id'), fn ($q) => $q->where('product_color_id', $request->integer('product_color_id')))
            ->when($request->filled('barcode'),          fn ($q) => $q->where('barcode_value', $request->barcode))
            ->latest()
            ->paginate($request->integer('per_page', 50));

        return ProductVariantResource::collection($variants);
    }

    /**
     * GET /api/v1/product-variants/barcode/{barcode}
     *
     * Resolve a single variant by its barcode value.
     * Called when the client scans a barcode label.
     */
    public function findByBarcode(string $barcode): JsonResponse
    {
        $variant = ProductVariant::with(['productColor.product.productType', 'productColor.product.productQuality', 'productColor.color', 'productSize'])
            ->where('barcode_value', $barcode)
            ->firstOrFail();

        return response()->json(['data' => new ProductVariantResource($variant)]);
    }
}
