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
            // decimal:3 (step 08) makes the model attribute a string; cast back
            // to float here so the API keeps returning a JSON number. The
            // Flutter client parses this as `(json['quantity'] as num)`, which
            // throws on a JSON string. See
            // instructions/phase-1/08-raw-material-validation-decimal.md.
            'quantity'    => (float) $this->quantity,
            'notes'       => $this->notes,
            'created_at'  => $this->created_at?->toISOString(),
        ];
    }
}
