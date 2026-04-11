<?php

namespace App\Http\Requests\Production;

use Illuminate\Foundation\Http\FormRequest;

class StoreDefectDocumentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'description'              => ['required', 'string', 'min:5'],
            'datetime'                 => ['nullable', 'date'],
            'items'                    => ['required', 'array', 'min:1'],
            'items.*.production_batch_item_id' => ['required', 'integer', 'exists:production_batch_items,id'],
            'items.*.quantity'         => ['required', 'integer', 'min:1'],
            'photos'                   => ['nullable', 'array'],
            'photos.*'                 => ['file', 'image', 'max:10240'],
        ];
    }

    public function messages(): array
    {
        return [
            'description.required' => 'Izoh maydoni majburiy.',
            'description.min'      => 'Izoh kamida 5 ta belgidan iborat bo\'lishi kerak.',
            'items.required'       => 'Kamida bitta mahsulot tanlanishi kerak.',
            'items.min'            => 'Kamida bitta mahsulot tanlanishi kerak.',
            'items.*.production_batch_item_id.required' => 'Partiya mahsuloti majburiy.',
            'items.*.production_batch_item_id.exists'   => 'Partiya mahsuloti topilmadi.',
            'items.*.quantity.required' => 'Miqdor majburiy.',
            'items.*.quantity.min'      => 'Miqdor 1 dan kam bo\'lmasligi kerak.',
            'photos.*.image'       => 'Fayl rasm formatida bo\'lishi kerak.',
            'photos.*.max'         => 'Rasm hajmi 10 MB dan oshmasligi kerak.',
        ];
    }
}
