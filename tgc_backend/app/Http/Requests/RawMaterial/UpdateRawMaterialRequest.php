<?php

namespace App\Http\Requests\RawMaterial;

use App\Models\RawMaterial;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateRawMaterialRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $material = $this->route('rawMaterial');

        return [
            'name' => [
                'sometimes',
                'required',
                'string',
                'max:255',
                Rule::unique('raw_materials')
                    ->where(fn ($q) => $q->where('type', $this->type ?? $material->type))
                    ->ignore($material->id),
            ],
            'type' => ['sometimes', 'required', 'string', 'max:255'],
            'unit' => ['sometimes', 'required', Rule::in(RawMaterial::UNITS)],
        ];
    }
}
