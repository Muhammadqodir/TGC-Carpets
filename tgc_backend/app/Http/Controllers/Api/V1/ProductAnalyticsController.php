<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Analytics\ProductAnalyticsRequest;
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
}
