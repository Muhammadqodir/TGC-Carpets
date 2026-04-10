<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'       => $this->id,
            'quantity' => $this->quantity,
            'variant'  => $this->whenLoaded('variant', fn () => [
                'id'            => $this->variant->id,
                'barcode_value' => $this->variant->barcode_value,
                'sku_code'      => $this->variant->sku_code,
                'product_color' => $this->variant->relationLoaded('productColor') && $this->variant->productColor
                    ? [
                        'id'        => $this->variant->productColor->id,
                        'image_url' => $this->variant->productColor->image
                            ? Storage::disk('public')->url($this->variant->productColor->image)
                            : null,
                        'color' => $this->variant->productColor->relationLoaded('color') && $this->variant->productColor->color
                            ? ['id' => $this->variant->productColor->color->id, 'name' => $this->variant->productColor->color->name]
                            : null,
                        'product' => $this->variant->productColor->relationLoaded('product') && $this->variant->productColor->product
                            ? [
                                'id'              => $this->variant->productColor->product->id,
                                'name'            => $this->variant->productColor->product->name,
                                'unit'            => $this->variant->productColor->product->unit,
                                'product_type_id' => $this->variant->productColor->product->product_type_id,
                                'product_type'    => $this->variant->productColor->product->relationLoaded('productType') && $this->variant->productColor->product->productType
                                    ? [
                                        'id'   => $this->variant->productColor->product->productType->id,
                                        'type' => $this->variant->productColor->product->productType->type,
                                      ]
                                    : null,
                                'quality_name'    => $this->variant->productColor->product->relationLoaded('productQuality') && $this->variant->productColor->product->productQuality
                                    ? $this->variant->productColor->product->productQuality->quality_name
                                    : null,
                            ]
                            : null,
                    ]
                    : null,
                'product_size' => $this->variant->relationLoaded('productSize') && $this->variant->productSize
                    ? [
                        'id'     => $this->variant->productSize->id,
                        'length' => $this->variant->productSize->length,
                        'width'  => $this->variant->productSize->width,
                    ]
                    : null,
            ]),
        ];
    }
}
