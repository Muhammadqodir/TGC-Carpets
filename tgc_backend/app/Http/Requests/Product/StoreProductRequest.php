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
            'name'     => ['required', 'string', 'max:255'],
            'barcode'  => ['nullable', 'string', 'max:100', Rule::unique('products', 'barcode')],
            'length'   => ['required', 'integer', 'min:1'],
            'width'    => ['required', 'integer', 'min:1'],
            'quality'  => ['required', 'string', 'max:100'],
            'density'  => ['required', 'integer', 'min:1'],
            'color'    => ['required', 'string', 'max:100'],
            'edge'     => ['nullable', 'string', 'max:100'],
            'unit'     => ['required', 'string', Rule::in(Product::UNITS)],
            'status'   => ['nullable', 'string', Rule::in(Product::STATUSES)],
            'image'    => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ];
    }
}
