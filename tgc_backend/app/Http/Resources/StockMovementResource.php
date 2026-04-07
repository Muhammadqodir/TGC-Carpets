<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StockMovementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                      => $this->id,
            'uuid'                    => $this->uuid,
            'movement_type'           => $this->movement_type,
            'quantity'                => $this->quantity,
            'movement_date'           => $this->movement_date?->toISOString(),
            'notes'                   => $this->notes,
            'variant'                 => $this->whenLoaded('variant', fn () => [
                'id'            => $this->variant->id,
                'barcode_value' => $this->variant->barcode_value,
                'sku_code'      => $this->variant->sku_code,
            ]),
            'product'                 => $this->whenLoaded('variant', fn () => $this->variant->productColor?->product ? [
                'id'   => $this->variant->productColor->product->id,
                'name' => $this->variant->productColor->product->name,
            ] : null),
            'color'                   => $this->whenLoaded('variant', fn () => $this->variant->productColor?->color ? [
                'id'   => $this->variant->productColor->color->id,
                'name' => $this->variant->productColor->color->name,
            ] : null),
            'product_size'            => $this->whenLoaded('variant', fn () => $this->variant->productSize ? [
                'id'     => $this->variant->productSize->id,
                'length' => $this->variant->productSize->length,
                'width'  => $this->variant->productSize->width,
            ] : null),
            'warehouse_document_id'   => $this->warehouse_document_id,
            'sale_id'                 => $this->sale_id,
            'client'                  => $this->whenLoaded('client', fn () => $this->client ? [
                'id'        => $this->client->id,
                'shop_name' => $this->client->shop_name,
            ] : null),
            'user'                    => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
