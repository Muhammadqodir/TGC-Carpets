<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductAnalyticsResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'period'       => $this->resource['period'],
            'summary'      => $this->resource['summary'],
            'trend'        => $this->resource['trend'],
            'by_type'      => $this->resource['by_type'],
            'by_color'     => $this->resource['by_color'],
            'by_size'      => $this->resource['by_size'],
            'by_quality'   => $this->resource['by_quality'],
            'by_edge'      => $this->resource['by_edge'],
            'top_products' => $this->resource['top_products'],
        ];
    }
}
