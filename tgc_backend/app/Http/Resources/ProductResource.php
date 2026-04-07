<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'              => $this->id,
            'uuid'            => $this->uuid,
            'name'            => $this->name,
            'product_type_id'    => $this->product_type_id,
            'product_type'       => new ProductTypeResource($this->whenLoaded('productType')),
            'product_quality_id' => $this->product_quality_id,
            'product_quality'    => new ProductQualityResource($this->whenLoaded('productQuality')),
            'unit'            => $this->unit,
            'status'          => $this->status,            'product_colors'  => $this->whenLoaded('productColors', fn () => $this->productColors->map(fn ($pc) => [
                'id'        => $pc->id,
                'color'     => [
                    'id'   => $pc->color->id,
                    'name' => $pc->color->name,
                ],
                'image_url' => $pc->image ? Storage::disk('public')->url($pc->image) : null,
            ])),
            'stock'           => (int) ($this->stock ?? 0),
            'created_at'      => $this->created_at?->toISOString(),
            'updated_at'      => $this->updated_at?->toISOString(),
        ];
    }
}
