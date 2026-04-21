<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RawMaterialStockMovementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'          => $this->id,
            'material_id' => $this->material_id,
            'material'    => $this->whenLoaded('material', fn () => [
                'id'   => $this->material->id,
                'name' => $this->material->name,
                'type' => $this->material->type,
                'unit' => $this->material->unit,
            ]),
            'user'        => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'date_time'   => $this->date_time?->toISOString(),
            'type'        => $this->type,
            'quantity'    => $this->quantity,
            'notes'       => $this->notes,
            'created_at'  => $this->created_at?->toISOString(),
        ];
    }
}
