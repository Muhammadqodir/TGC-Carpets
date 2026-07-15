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

    /**
     * GET /api/v1/analytics/production/compare
     *
     * Admin-only diagnostic for phase-2 step 04's rollout: legacy vs
     * event-sourced numbers side by side, with the per-period delta. Not
     * for general use — deliberately not exposed to normal roles, and
     * intended to be deleted along with the legacy path once
     * ANALYTICS_SOURCE=events has shipped and been confirmed. See
     * instructions/phase-2/04-repoint-analytics-to-occurred-at.md "Rollout".
     */
    public function compare(ProductionAnalyticsRequest $request): JsonResponse
    {
        $result = $this->analyticsService->compare(
            from:    $request->periodFrom(),
            to:      $request->periodTo(),
            trendBy: $request->trendBy(),
        );

        return response()->json([
            'period' => [
                'from'     => $request->periodFrom(),
                'to'       => $request->periodTo(),
                'trend_by' => $request->trendBy(),
            ],
            ...$result,
        ]);
    }
}
