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
            'length'       => $this->whenLoaded('variant', fn () => $this->variant->length),
            'width'        => $this->whenLoaded('variant', fn () => $this->variant->width),
            'quantity'     => $this->quantity,
            'price'        => $this->price,
            'total'        => $this->computeTotal(),
            'order'        => $this->whenLoaded('orderItem', fn () => $this->orderItem?->order ? [
                'id'         => $this->orderItem->order->id,
                'order_date' => $this->orderItem->order->order_date?->toDateString(),
            ] : null),
        ];
    }

    private function computeTotal(): float
    {
        $qty   = $this->quantity;
        $price = (float) $this->price;
        $unit  = $this->variant?->productColor?->product?->unit ?? 'piece';

        if ($unit === 'm2') {
            $l = $this->variant?->length;
            $w = $this->variant?->width;
            if ($l && $w) {
                $sqm = $l * $w * $qty / 10000.0;
                return round($price * $sqm, 2);
            }
        }

        return round($price * $qty, 2);
    }
}
