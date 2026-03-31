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
            'client_id'             => ['nullable', 'integer', 'exists:clients,id'],
            'document_date'         => ['required', 'date'],
            'notes'                 => ['nullable', 'string'],

            'items'                 => ['required', 'array', 'min:1'],
            'items.*.product_id'    => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity'      => ['required', 'integer', 'min:1'],
            'items.*.notes'         => ['nullable', 'string'],
        ];
    }
}
