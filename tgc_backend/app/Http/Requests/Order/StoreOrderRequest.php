<?php

namespace App\Http\Requests\Order;

use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;

class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id'       => ['required', 'integer', 'exists:clients,id'],
            'status'          => ['sometimes', 'string', 'in:' . implode(',', Order::STATUSES)],
            'order_date'      => ['required', 'date'],
            'notes'           => ['nullable', 'string', 'max:1000'],
            'external_uuid'   => ['nullable', 'string', 'max:255'],
            'items'                    => ['required', 'array', 'min:1'],
            'items.*.product_color_id'  => ['required', 'integer', 'exists:product_colors,id'],
            'items.*.length'             => ['nullable', 'integer', 'min:1'],
            'items.*.width'              => ['nullable', 'integer', 'min:1'],
            'items.*.quantity'          => ['required', 'integer', 'min:1'],
        ];
    }
}
