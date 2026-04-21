<?php

namespace App\Http\Requests\RawMaterial;

use App\Models\RawMaterial;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreRawMaterialRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => [
                'required',
                'string',
                'max:255',
                Rule::unique('raw_materials')->where(fn ($q) => $q->where('type', $this->type)),
            ],
            'type' => ['required', 'string', 'max:255'],
            'unit' => ['required', Rule::in(RawMaterial::UNITS)],
        ];
    }
}
