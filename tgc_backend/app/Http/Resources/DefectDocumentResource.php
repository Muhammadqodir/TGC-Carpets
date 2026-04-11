<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DefectDocumentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                  => $this->id,
            'production_batch_id' => $this->production_batch_id,
            'datetime'            => $this->datetime?->toISOString(),
            'description'         => $this->description,
            'user'                => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'production_batch'    => $this->whenLoaded('productionBatch', fn () => [
                'id'          => $this->productionBatch->id,
                'batch_title' => $this->productionBatch->batch_title,
                'status'      => $this->productionBatch->status,
            ]),
            'items'  => DefectDocumentItemResource::collection($this->whenLoaded('items')),
            'photos' => DefectDocumentPhotoResource::collection($this->whenLoaded('photos')),
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }
}
