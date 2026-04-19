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
            'document_date'      => ['sometimes', 'required', 'date'],
            'notes'              => ['nullable', 'string'],

            // Updating items replaces them entirely
            'items'                    => ['sometimes', 'required', 'array', 'min:1'],
            'items.*.product_id'       => ['required_with:items', 'integer', 'exists:products,id'],
            'items.*.length'           => ['nullable', 'integer', 'min:1'],
            'items.*.width'            => ['nullable', 'integer', 'min:1'],
            'items.*.quantity'         => ['required_with:items', 'integer', 'min:1'],
            'items.*.source_type'      => ['nullable', 'string', Rule::in(['shipment_item', 'production_batch_item'])],
            'items.*.source_id'        => ['nullable', 'integer', 'min:1'],
            'items.*.notes'            => ['nullable', 'string'],
        ];
    }
}
