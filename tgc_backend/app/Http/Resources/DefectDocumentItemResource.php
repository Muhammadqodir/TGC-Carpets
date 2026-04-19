<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class DefectDocumentItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                        => $this->id,
            'defect_document_id'        => $this->defect_document_id,
            'production_batch_item_id'  => $this->production_batch_item_id,
            'quantity'                  => $this->quantity,
            'batch_item'                => $this->whenLoaded('productionBatchItem', function () {
                $item = $this->productionBatchItem;
                if (! $item) {
                    return null;
                }

                return [
                    'id'               => $item->id,
                    'planned_quantity' => $item->planned_quantity,
                    'product_name'     => $item->relationLoaded('variant') && $item->variant?->relationLoaded('productColor') && $item->variant->productColor?->relationLoaded('product')
                        ? $item->variant->productColor->product?->name
                        : null,
                    'color_name'       => $item->relationLoaded('variant') && $item->variant?->relationLoaded('productColor') && $item->variant->productColor?->relationLoaded('color')
                        ? $item->variant->productColor->color?->name
                        : null,
                    'image_url'        => $item->relationLoaded('variant') && $item->variant?->relationLoaded('productColor') && $item->variant->productColor?->image
                        ? Storage::disk('public')->url($item->variant->productColor->image)
                        : null,
                    'size_length'      => $item->relationLoaded('variant')
                        ? $item->variant?->length
                        : null,
                    'size_width'       => $item->relationLoaded('variant')
                        ? $item->variant?->width
                        : null,
                ];
            }),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
