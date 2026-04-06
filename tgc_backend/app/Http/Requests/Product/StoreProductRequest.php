<?php

namespace App\Http\Requests\Product;

use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name'            => ['required', 'string', 'max:255'],
            'product_type_id'    => ['nullable', 'integer', 'exists:product_types,id'],
            'product_quality_id' => ['nullable', 'integer', 'exists:product_qualities,id'],
            'color'           => ['required', 'string', 'max:100'],
            'unit'            => ['required', 'string', Rule::in(Product::UNITS)],
            'status'          => ['nullable', 'string', Rule::in(Product::STATUSES)],
            'image'           => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ];
    }
}
