<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PaymentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'     => $this->id,
            'amount' => (float) $this->amount,
            'notes'  => $this->notes,
            'client' => $this->whenLoaded('client', fn () => [
                'id'        => $this->client->id,
                'shop_name' => $this->client->shop_name,
                'region'    => $this->client->region,
            ]),
            'user'   => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'order'  => $this->whenLoaded('order', fn () => $this->order
                ? ['id' => $this->order->id]
                : null),
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
