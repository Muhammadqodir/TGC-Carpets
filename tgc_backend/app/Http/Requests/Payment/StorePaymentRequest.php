<?php

namespace App\Http\Requests\Payment;

use Illuminate\Foundation\Http\FormRequest;

class StorePaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id' => ['required', 'integer', 'exists:clients,id'],
            'order_id'  => ['nullable', 'integer', 'exists:orders,id'],
            'amount'    => ['required', 'numeric', 'min:0.01'],
            'notes'     => ['nullable', 'string', 'max:2000'],
        ];
    }
}
