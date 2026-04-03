<?php

namespace App\Http\Requests\Sale;

use Illuminate\Foundation\Http\FormRequest;

class UpdateSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id'           => ['sometimes', 'required', 'integer', 'exists:clients,id'],
            'sale_date'           => ['sometimes', 'required', 'date'],
            'notes'               => ['nullable', 'string'],

            // Supplying items replaces all existing items
            'items'               => ['sometimes', 'required', 'array', 'min:1'],
            'items.*.product_id'  => ['required_with:items', 'integer', 'exists:products,id'],
            'items.*.quantity'    => ['required_with:items', 'integer', 'min:1'],
            'items.*.price'       => ['required_with:items', 'numeric', 'min:0'],
        ];
    }
}
