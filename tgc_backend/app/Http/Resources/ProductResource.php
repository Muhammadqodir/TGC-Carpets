<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

// ProductTypeResource lives in the same namespace — no extra import needed

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'              => $this->id,
            'uuid'            => $this->uuid,
            'name'            => $this->name,
            'sku_code'        => $this->sku_code,
            'barcode'         => $this->barcode,
            'product_type_id'    => $this->product_type_id,
            'product_type'       => new ProductTypeResource($this->whenLoaded('productType')),
            'product_quality_id' => $this->product_quality_id,
            'product_quality'    => new ProductQualityResource($this->whenLoaded('productQuality')),
            'color'           => $this->color,
            'edge'            => $this->edge,
            'unit'            => $this->unit,
            'status'          => $this->status,
            'image_url'       => $this->image ? Storage::disk('public')->url($this->image) : null,
            'stock'           => (int) ($this->stock ?? 0),
            'created_at'      => $this->created_at?->toISOString(),
            'updated_at'      => $this->updated_at?->toISOString(),
        ];
    }
}
