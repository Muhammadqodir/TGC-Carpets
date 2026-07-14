<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Analytics\ProductionAnalyticsRequest;
use App\Http\Resources\ProductionAnalyticsResource;
use App\Services\ProductionAnalyticsService;
use Illuminate\Http\JsonResponse;

class ProductionAnalyticsController extends Controller
{
    public function __construct(
        private readonly ProductionAnalyticsService $analyticsService,
    ) {}

    /**
     * GET /api/v1/analytics/production
     *
     * Query params:
     *   period_from  (date, default: today − 30 days)
     *   period_to    (date, default: today)
     *   trend_by     (day|week|month, default: day)
     */
    public function index(ProductionAnalyticsRequest $request): JsonResponse
    {
        $report = $this->analyticsService->getReport(
            from:    $request->periodFrom(),
            to:      $request->periodTo(),
            trendBy: $request->trendBy(),
        );

        return (new ProductionAnalyticsResource([
            'period' => [
                'from'     => $request->periodFrom(),
                'to'       => $request->periodTo(),
                'trend_by' => $request->trendBy(),
            ],
            ...$report,
        ]))->response();
    }
}
