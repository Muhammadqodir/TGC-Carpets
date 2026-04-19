<?php

namespace App\Http\Requests\Order;

use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;

class UpdateOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id'  => ['nullable', 'integer', 'exists:clients,id'],
            'status'     => ['sometimes', 'string', 'in:' . implode(',', Order::STATUSES)],
            'order_date' => ['sometimes', 'date'],
            'notes'      => ['nullable', 'string', 'max:1000'],
            'items'                   => ['sometimes', 'array', 'min:1'],
            'items.*.product_color_id' => ['required_with:items', 'integer', 'exists:product_colors,id'],
            'items.*.length'            => ['nullable', 'integer', 'min:1'],
            'items.*.width'             => ['nullable', 'integer', 'min:1'],
            'items.*.quantity'         => ['required_with:items', 'integer', 'min:1'],
        ];
    }
}
