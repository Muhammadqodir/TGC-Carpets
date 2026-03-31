<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ClientResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'           => $this->id,
            'uuid'         => $this->uuid,
            'contact_name' => $this->contact_name,
            'phone'        => $this->phone,
            'shop_name'    => $this->shop_name,
            'region'       => $this->region,
            'address'      => $this->address,
            'notes'        => $this->notes,
            'created_at'   => $this->created_at?->toISOString(),
            'updated_at'   => $this->updated_at?->toISOString(),
        ];
    }
}
