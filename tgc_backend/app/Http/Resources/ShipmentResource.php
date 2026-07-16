<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class ShipmentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'                => $this->id,
            'shipment_datetime' => $this->shipment_datetime?->toISOString(),
            'notes'             => $this->notes,
            'currency'          => $this->currency,
            'currency_symbol'   => $this->resource->currencySymbol(),
            'exchange_rate'     => $this->exchange_rate,
            'vat_rate'          => $this->vat_rate,
            'vat_amount'        => $this->vat_amount,
            'subtotal'          => $this->whenLoaded('items', fn () => $this->resource->subtotal()),
            'total'             => $this->whenLoaded('items', fn () => $this->resource->total()),
            'pdf_url'           => $this->pdf_path
                ? Storage::disk('public')->url($this->pdf_path)
                : null,
            'invoice_url'       => $this->invoice_path
                ? Storage::disk('public')->url($this->invoice_path)
                : null,
            'xlsx_url'          => $this->xlsx_path
                ? Storage::disk('public')->url($this->xlsx_path)
                : null,
            'client'            => $this->whenLoaded('client', fn () => [
                'id'        => $this->client->id,
                'shop_name' => $this->client->shop_name,
                'region'    => $this->client->region,
            ]),
            'user'              => $this->whenLoaded('user', fn () => [
                'id'   => $this->user->id,
                'name' => $this->user->name,
            ]),
            'items'             => ShipmentItemResource::collection($this->whenLoaded('items')),
            'created_at'        => $this->created_at?->toISOString(),
            'updated_at'        => $this->updated_at?->toISOString(),
        ];
    }
}
