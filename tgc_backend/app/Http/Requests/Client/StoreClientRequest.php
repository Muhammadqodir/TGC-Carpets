<?php

namespace App\Http\Requests\Client;

use Illuminate\Foundation\Http\FormRequest;

class StoreClientRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'contact_name'  => ['nullable', 'string', 'max:255'],
            'phone'         => ['nullable', 'string', 'max:30'],
            'shop_name'     => ['required', 'string', 'max:255'],
            'region'        => ['required', 'string', 'max:100'],
            'address'       => ['nullable', 'string'],
            'notes'         => ['nullable', 'string'],
            'external_uuid' => ['nullable', 'uuid'],
        ];
    }
}
