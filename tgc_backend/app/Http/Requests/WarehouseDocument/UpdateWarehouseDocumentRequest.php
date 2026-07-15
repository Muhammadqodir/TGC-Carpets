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
            // 'type' changes the meaning of every stock movement on this document, so it
            // may only be submitted together with 'items' (a full item replacement) —
            // never on its own. See instructions/phase-0/03.
            'type'               => ['sometimes', 'required', 'string', Rule::in(WarehouseDocument::TYPES), 'required_with:items'],
            'document_date'      => ['sometimes', 'required', 'date'],
            'notes'              => ['nullable', 'string'],

            // Updating items replaces them entirely
            'items'                     => ['sometimes', 'required', 'array', 'min:1', 'required_with:type'],
            'items.*.product_id'        => ['required_with:items', 'integer', 'exists:products,id'],
            'items.*.product_color_id'  => ['required_with:items', 'integer', 'exists:product_colors,id'],
            'items.*.product_size_id'   => ['nullable', 'integer', 'exists:product_sizes,id'],
            'items.*.quantity'          => ['required_with:items', 'integer', 'min:1'],
            'items.*.source_type'       => ['nullable', 'string', Rule::in(['shipment_item', 'production_batch_item'])],
            'items.*.source_id'         => ['nullable', 'integer', 'min:1'],
            'items.*.notes'             => ['nullable', 'string'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            if ($this->has('type') && ! $this->has('items')) {
                $validator->errors()->add(
                    'type',
                    'Hujjat turini o\'zgartirish uchun mahsulotlar ro\'yxati ham yuborilishi kerak.'
                );
            }
        });
    }
}
