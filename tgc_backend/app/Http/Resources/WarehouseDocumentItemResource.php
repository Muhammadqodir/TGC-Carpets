<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WarehouseDocumentItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'product'      => $this->whenLoaded('product', fn () => [
                'id'       => $this->product->id,
                'name'     => $this->product->name,
                'sku_code' => $this->product->sku_code,
                'unit'     => $this->product->unit,
            ]),
            'product_size' => $this->whenLoaded('productSize', fn () => $this->productSize ? [
                'id'     => $this->productSize->id,
                'length' => $this->productSize->length,
                'width'  => $this->productSize->width,
            ] : null),
            'quantity'     => $this->quantity,
            'notes'        => $this->notes,
        ];
    }
}
