<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Analytics\ProductAnalyticsRequest;
use App\Http\Requests\Analytics\TopProductsFilterRequest;
use App\Http\Resources\ProductAnalyticsResource;
use App\Services\ProductAnalyticsService;
use Illuminate\Http\JsonResponse;

class ProductAnalyticsController extends Controller
{
    public function __construct(
        private readonly ProductAnalyticsService $analyticsService,
    ) {}

    /**
     * GET /api/v1/analytics/products
     *
     * Query params:
     *   period_from  (date, default: today − 30 days)
     *   period_to    (date, default: today)
     *   trend_by     (day|week|month, default: day)
     */
    public function index(ProductAnalyticsRequest $request): JsonResponse
    {
        $report = $this->analyticsService->getReport(
            from:    $request->periodFrom(),
            to:      $request->periodTo(),
            trendBy: $request->trendBy(),
        );

        return (new ProductAnalyticsResource([
            'period' => [
                'from'     => $request->periodFrom(),
                'to'       => $request->periodTo(),
                'trend_by' => $request->trendBy(),
            ],
            ...$report,
        ]))->response();
    }

    /**
     * GET /api/v1/analytics/top-products
     *
     * Query params:
     *   period_from  (date, default: today − 30 days)
     *   period_to    (date, default: today)
     *   type_id      (integer, optional)
     *   quality_id   (integer, optional)
     *   color_id     (integer, optional)
     *   size_id      (integer, optional)
     *   edge_id      (integer, optional)
     *   limit        (10|20|30|40|50, default: 10)
     */
    public function topProducts(TopProductsFilterRequest $request): JsonResponse
    {
        $products = $this->analyticsService->getFilteredTopProducts(
            from:      $request->periodFrom(),
            to:        $request->periodTo(),
            typeId:    $request->typeId(),
            qualityId: $request->qualityId(),
            colorId:   $request->colorId(),
            sizeId:    $request->sizeId(),
            edgeId:    $request->edgeId(),
            limit:     $request->limit(),
        );

        return response()->json(['data' => ['top_products' => $products]]);
    }
}
