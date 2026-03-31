<?php

namespace App\Http\Requests\Client;

use Illuminate\Foundation\Http\FormRequest;

class UpdateClientRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'contact_name' => ['sometimes', 'required', 'string', 'max:255'],
            'phone'        => ['sometimes', 'required', 'string', 'max:30'],
            'shop_name'    => ['sometimes', 'required', 'string', 'max:255'],
            'region'       => ['sometimes', 'required', 'string', 'max:100'],
            'address'      => ['nullable', 'string'],
            'notes'        => ['nullable', 'string'],
        ];
    }
}
