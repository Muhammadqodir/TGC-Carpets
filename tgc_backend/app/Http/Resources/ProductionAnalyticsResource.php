<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductionAnalyticsResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'period'       => $this->resource['period'],
            'summary'      => $this->resource['summary'],
            'trend'        => $this->resource['trend'],
            // Bucketed on a DIFFERENT clock than `trend` under the legacy
            // source (defect_documents.datetime vs
            // production_batch_items.updated_at) — do not plot the two on
            // one axis as if they were directly comparable period-by-period.
            // See instructions/phase-3/08-defect-rate-and-yield-metrics.md.
            'defect_trend' => $this->resource['defect_trend'],
            'by_type'      => $this->resource['by_type'],
            'by_color'     => $this->resource['by_color'],
            'by_size'      => $this->resource['by_size'],
            'by_quality'   => $this->resource['by_quality'],
            'by_edge'      => $this->resource['by_edge'],
            'by_machine'   => $this->resource['by_machine'],
        ];
    }
}
