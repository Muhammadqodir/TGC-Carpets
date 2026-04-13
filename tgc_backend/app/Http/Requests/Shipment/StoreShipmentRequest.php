<?php

namespace App\Http\Requests\Shipment;

use Illuminate\Foundation\Http\FormRequest;

class StoreShipmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id'               => ['required', 'integer', 'exists:clients,id'],
            'order_id'                => ['nullable', 'integer', 'exists:orders,id'],
            'shipment_datetime'       => ['required', 'date'],
            'notes'                   => ['nullable', 'string', 'max:2000'],

            'items'                          => ['required', 'array', 'min:1'],
            'items.*.order_item_id'          => ['required', 'integer', 'exists:order_items,id'],
            'items.*.product_variant_id'     => ['required', 'integer', 'exists:product_variants,id'],
            'items.*.quantity'               => ['required', 'integer', 'min:1'],
            'items.*.price'                  => ['required', 'numeric', 'min:0'],
        ];
    }
}
