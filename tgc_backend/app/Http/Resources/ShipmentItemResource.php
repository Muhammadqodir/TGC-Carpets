<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ShipmentItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'variant'      => $this->whenLoaded('variant', fn () => [
                'id'            => $this->variant->id,
                'barcode_value' => $this->variant->barcode_value,
                'sku_code'      => $this->variant->sku_code,
            ]),
            'product'      => $this->whenLoaded('variant', fn () => $this->variant->productColor?->product ? [
                'id'   => $this->variant->productColor->product->id,
                'name' => $this->variant->productColor->product->name,
                'unit' => $this->variant->productColor->product->unit,
            ] : null),
            'color'        => $this->whenLoaded('variant', fn () => $this->variant->productColor?->color ? [
                'id'   => $this->variant->productColor->color->id,
                'name' => $this->variant->productColor->color->name,
            ] : null),
            'product_size' => $this->whenLoaded('variant', fn () => $this->variant->productSize ? [
                'id'     => $this->variant->productSize->id,
                'length' => $this->variant->productSize->length,
                'width'  => $this->variant->productSize->width,
            ] : null),
            'quantity'     => $this->quantity,
            'price'        => $this->price,
            'total'        => $this->total,
        ];
    }
}
