<?php

namespace App\Http\Requests\ProductSize;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductSizeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $sizeId = $this->route('product_size')?->id;

        return [
            'length'          => ['sometimes', 'required', 'integer', 'min:1'],
            'width'           => ['sometimes', 'required', 'integer', 'min:1'],
            'product_type_id' => [
                'sometimes',
                'required',
                'integer',
                'exists:product_types,id',
                Rule::unique('product_sizes')->where(function ($query) {
                    return $query
                        ->where('length', $this->input('length'))
                        ->where('width',  $this->input('width'));
                })->ignore($sizeId),
            ],
        ];
    }
}
