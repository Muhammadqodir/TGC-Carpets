<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'         => $this->id,
            'uuid'       => $this->uuid,
            'name'       => $this->name,
            'sku_code'   => $this->sku_code,
            'barcode'    => $this->barcode,
            'length'     => $this->length,
            'width'      => $this->width,
            'quality'    => $this->quality,
            'density'    => $this->density,
            'color'      => $this->color,
            'edge'       => $this->edge,
            'unit'       => $this->unit,
            'status'     => $this->status,
            'image_url'  => $this->image ? Storage::disk('public')->url($this->image) : null,
            'stock'      => $this->whenLoaded('stockMovements', fn () => $this->currentStock()),
            'created_at' => $this->created_at?->toISOString(),
            'updated_at' => $this->updated_at?->toISOString(),
        ];
    }

    private function currentStock(): int
    {
        return $this->stockMovements->sum(fn ($m) => $m->isIncoming() ? $m->quantity : -$m->quantity);
    }
}
