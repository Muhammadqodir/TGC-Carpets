<?php

namespace App\Http\Requests\Sale;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'external_uuid'       => ['nullable', 'uuid', Rule::unique('sales', 'external_uuid')],
            'client_id'           => ['required', 'integer', 'exists:clients,id'],
            'sale_date'           => ['required', 'date'],
            'notes'               => ['nullable', 'string'],

            'items'               => ['required', 'array', 'min:1'],
            'items.*.product_id'  => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity'    => ['required', 'integer', 'min:1'],
            'items.*.price'       => ['required', 'numeric', 'min:0'],
        ];
    }
}
