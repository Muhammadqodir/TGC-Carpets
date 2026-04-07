<?php

namespace App\Http\Requests\WarehouseDocument;

use App\Models\WarehouseDocument;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateWarehouseDocumentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type'               => ['sometimes', 'required', 'string', Rule::in(WarehouseDocument::TYPES)],
            'client_id'          => ['nullable', 'integer', 'exists:clients,id'],
            'document_date'      => ['sometimes', 'required', 'date'],
            'notes'              => ['nullable', 'string'],

            // Updating items replaces them entirely
            'items'                    => ['sometimes', 'required', 'array', 'min:1'],
            'items.*.product_id'       => ['required_with:items', 'integer', 'exists:products,id'],
            'items.*.product_size_id'  => ['nullable', 'integer', 'exists:product_sizes,id'],
            'items.*.quantity'         => ['required_with:items', 'integer', 'min:1'],
            'items.*.notes'            => ['nullable', 'string'],
        ];
    }
}
