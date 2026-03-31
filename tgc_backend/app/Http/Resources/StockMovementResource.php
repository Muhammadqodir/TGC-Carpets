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
            'product'                 => $this->whenLoaded('product', fn () => [
                'id'       => $this->product->id,
                'name'     => $this->product->name,
                'sku_code' => $this->product->sku_code,
            ]),
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
