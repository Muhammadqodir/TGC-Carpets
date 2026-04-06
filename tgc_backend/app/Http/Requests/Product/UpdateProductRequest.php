<?php

namespace App\Http\Requests\Product;

use App\Models\Product;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $productId = $this->route('product')->id;

        return [
            'name'            => ['sometimes', 'required', 'string', 'max:255'],
            'barcode'         => ['nullable', 'string', 'max:100', Rule::unique('products', 'barcode')->ignore($productId)],
            'product_type_id' => ['nullable', 'integer', 'exists:product_types,id'],
            'quality'         => ['sometimes', 'required', 'string', 'max:100'],
            'density'         => ['sometimes', 'required', 'integer', 'min:1'],
            'color'           => ['sometimes', 'required', 'string', 'max:100'],
            'edge'            => ['nullable', 'string', 'max:100'],
            'unit'            => ['sometimes', 'required', 'string', Rule::in(Product::UNITS)],
            'status'          => ['nullable', 'string', Rule::in(Product::STATUSES)],
            'image'           => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
        ];
    }
}
