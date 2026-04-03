<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SaleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'             => $this->id,
            'uuid'           => $this->uuid,
            'external_uuid'  => $this->external_uuid,
            'sale_date'      => $this->sale_date?->toISOString(),
            'total_amount'   => $this->total_amount,
            'notes'          => $this->notes,
            'client'         => $this->whenLoaded('client', fn () => [
                'id'        => $this->client->id,
                'shop_name' => $this->client->shop_name,
                'phone'     => $this->client->phone,
            ]),
            'user'           => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'items'          => SaleItemResource::collection($this->whenLoaded('items')),
            'created_at'     => $this->created_at?->toISOString(),
            'updated_at'     => $this->updated_at?->toISOString(),
        ];
    }
}
