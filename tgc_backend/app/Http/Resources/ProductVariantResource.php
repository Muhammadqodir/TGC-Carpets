<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductVariantResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'            => $this->id,
            'barcode_value' => $this->barcode_value,
            'sku_code'      => $this->sku_code,
            'product_color' => $this->whenLoaded('productColor', fn () => [
                'id'    => $this->productColor->id,
                'image' => $this->productColor->image,
                'color' => $this->productColor->relationLoaded('color') && $this->productColor->color
                    ? ['id' => $this->productColor->color->id, 'name' => $this->productColor->color->name]
                    : null,
                'product' => $this->productColor->relationLoaded('product') && $this->productColor->product
                    ? [
                        'id'              => $this->productColor->product->id,
                        'name'            => $this->productColor->product->name,
                        'unit'            => $this->productColor->product->unit,
                        'status'          => $this->productColor->product->status,
                        'product_type'    => $this->productColor->product->relationLoaded('productType') && $this->productColor->product->productType
                            ? ['id' => $this->productColor->product->productType->id, 'type' => $this->productColor->product->productType->type]
                            : null,
                        'product_quality' => $this->productColor->product->relationLoaded('productQuality') && $this->productColor->product->productQuality
                            ? ['id' => $this->productColor->product->productQuality->id, 'quality_name' => $this->productColor->product->productQuality->quality_name]
                            : null,
                    ]
                    : null,
            ]),
            'length'        => $this->length,
            'width'         => $this->width,
            'created_at'    => $this->created_at?->toISOString(),
        ];
    }
}
