<?php

namespace App\Http\Requests\ProductSize;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProductSizeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'length'          => ['required', 'integer', 'min:1'],
            'width'           => ['required', 'integer', 'min:1'],
            'product_type_id' => [
                'required',
                'integer',
                'exists:product_types,id',
                // Hidden (soft-deleted) sizes don't count: the controller restores them.
                Rule::unique('product_sizes')->where(function ($query) {
                    return $query
                        ->where('length', $this->input('length'))
                        ->where('width',  $this->input('width'))
                        ->whereNull('deleted_at');
                }),
            ],
        ];
    }
}
