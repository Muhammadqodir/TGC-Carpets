<?php

namespace App\Http\Resources;

use App\Http\Resources\ProductionBatchItemResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductionBatchResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                 => $this->id,
            'batch_title'        => $this->batch_title,
            'planned_datetime'   => $this->planned_datetime?->toISOString(),
            'started_datetime'   => $this->started_datetime?->toISOString(),
            'completed_datetime' => $this->completed_datetime?->toISOString(),
            'type'               => $this->type,
            'status'             => $this->status,
            'notes'              => $this->notes,
            'machine'            => $this->whenLoaded('machine', fn () => [
                'id'         => $this->machine->id,
                'name'       => $this->machine->name,
                'model_name' => $this->machine->model_name,
            ]),
            'creator'            => $this->whenLoaded('creator', fn () => [
                'id'   => $this->creator->id,
                'name' => $this->creator->name,
            ]),
            'items'              => ProductionBatchItemResource::collection($this->whenLoaded('items')),
            'items_count'        => $this->whenCounted('items'),
            'created_at'         => $this->created_at?->toISOString(),
            'updated_at'         => $this->updated_at?->toISOString(),
        ];
    }
}
