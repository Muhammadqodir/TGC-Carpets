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
            // max keeps values inside DECIMAL(12,3)'s range unconditionally.
            // decimal:0,3 (reject >3dp at the door) is gated behind the same
            // flag as the stock check — a UI computing 12.500000001 would
            // otherwise 422 with no warning. See
            // instructions/phase-1/08-raw-material-validation-decimal.md.
            'items.*.quantity'    => array_filter([
                'required',
                'numeric',
                'min:0.001',
                'max:999999999',
                config('raw_materials.enforce_stock_validation', false) ? 'decimal:0,3' : null,
            ]),
        ];
    }
}
