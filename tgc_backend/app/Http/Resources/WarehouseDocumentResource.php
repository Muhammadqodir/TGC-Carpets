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
            'source_type'   => $this->source_type,
            'source_id'     => $this->source_id,
            'document_date' => $this->document_date?->toISOString(),
            'notes'         => $this->notes,
            'user'          => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'pdf_url'       => $this->pdf_path ? asset('storage/' . $this->pdf_path) : null,
            'items'         => WarehouseDocumentItemResource::collection($this->whenLoaded('items')),
            'photos'        => WarehouseDocumentPhotoResource::collection($this->whenLoaded('photos')),
            'created_at'    => $this->created_at?->toISOString(),
            'updated_at'    => $this->updated_at?->toISOString(),
        ];
    }
}
