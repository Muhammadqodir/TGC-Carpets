<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductTypeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'type'         => $this->type,
            'status'       => $this->status,
            'is_printable' => (bool) $this->is_printable,
        ];
    }
}
