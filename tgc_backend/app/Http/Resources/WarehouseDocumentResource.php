<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class WarehouseDocumentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'            => $this->id,
            'uuid'          => $this->uuid,
            'external_uuid' => $this->external_uuid,
            'type'          => $this->type,
            'document_date' => $this->document_date?->toISOString(),
            'notes'         => $this->notes,
            'user'          => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'client'        => $this->whenLoaded('client', fn () => $this->client ? [
                'id'        => $this->client->id,
                'shop_name' => $this->client->shop_name,
            ] : null),
            'items'         => WarehouseDocumentItemResource::collection($this->whenLoaded('items')),
            'photos'        => WarehouseDocumentPhotoResource::collection($this->whenLoaded('photos')),
            'created_at'    => $this->created_at?->toISOString(),
            'updated_at'    => $this->updated_at?->toISOString(),
        ];
    }
}
