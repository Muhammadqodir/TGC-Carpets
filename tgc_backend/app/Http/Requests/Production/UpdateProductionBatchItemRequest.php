<?php

namespace App\Http\Requests\Production;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProductionBatchItemRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'produced_quantity' => ['sometimes', 'integer', 'min:0'],
            'defect_quantity'   => ['sometimes', 'integer', 'min:0'],
            'notes'             => ['nullable', 'string', 'max:1000'],
        ];
    }
}
