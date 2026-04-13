<?php

namespace App\Http\Requests\WarehouseDocument;

use App\Models\WarehouseDocument;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWarehouseDocumentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'external_uuid'         => ['nullable', 'uuid', Rule::unique('warehouse_documents', 'external_uuid')],
            'type'                  => ['required', 'string', Rule::in(WarehouseDocument::TYPES)],
            'source_type'           => ['nullable', 'string', Rule::in(['production', 'sale', 'other'])],
            'source_id'             => ['nullable', 'integer', 'min:1'],
            'document_date'         => ['required', 'date'],
            'notes'                 => ['nullable', 'string'],

            'items'                       => ['required', 'array', 'min:1'],
            'items.*.product_id'          => ['required', 'integer', 'exists:products,id'],
            'items.*.product_color_id'    => ['required', 'integer', 'exists:product_colors,id'],
            'items.*.product_size_id'     => ['required', 'integer', 'exists:product_sizes,id'],
            'items.*.quantity'            => ['required', 'integer', 'min:1'],
            'items.*.notes'               => ['nullable', 'string'],
        ];
    }
}
