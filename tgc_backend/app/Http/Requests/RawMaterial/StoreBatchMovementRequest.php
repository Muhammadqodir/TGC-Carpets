<?php

namespace App\Http\Requests\RawMaterial;

use App\Models\RawMaterialStockMovement;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreBatchMovementRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'date_time'           => ['required', 'date'],
            'type'                => ['required', Rule::in(RawMaterialStockMovement::TYPES)],
            'notes'               => ['nullable', 'string', 'max:1000'],
            'items'               => ['required', 'array', 'min:1'],
            'items.*.material_id' => ['required', 'integer', 'exists:raw_materials,id'],
            'items.*.quantity'    => ['required', 'numeric', 'min:0.001'],
        ];
    }
}
