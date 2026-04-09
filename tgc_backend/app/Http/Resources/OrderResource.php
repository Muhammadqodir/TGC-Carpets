<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'            => $this->id,
            'uuid'          => $this->uuid,
            'external_uuid' => $this->external_uuid,
            'status'        => $this->status,
            'order_date'    => $this->order_date?->toDateString(),
            'notes'         => $this->notes,
            'user'          => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'client'        => $this->whenLoaded('client', fn () => $this->client ? [
                'id'        => $this->client->id,
                'shop_name' => $this->client->shop_name,
                'phone'     => $this->client->phone,
            ] : null),
            'items'         => OrderItemResource::collection($this->whenLoaded('items')),
            'created_at'    => $this->created_at?->toISOString(),
            'updated_at'    => $this->updated_at?->toISOString(),
        ];
    }
}
