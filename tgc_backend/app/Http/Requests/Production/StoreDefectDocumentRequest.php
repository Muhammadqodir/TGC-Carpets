<?php

namespace App\Http\Requests\Production;

use App\Models\DefectDocumentItem;
use App\Models\ProductionBatchItem;
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

    public function withValidator($validator): void
    {
        $validator->after(function ($validator): void {
            $items = $this->input('items', []);

            foreach ($items as $index => $itemData) {
                $batchItemId = $itemData['production_batch_item_id'] ?? null;
                $quantity    = (int) ($itemData['quantity'] ?? 0);

                if (! $batchItemId) {
                    continue;
                }

                $batchItem = ProductionBatchItem::find($batchItemId);
                if (! $batchItem) {
                    continue;
                }

                $produced        = (int) ($batchItem->produced_quantity ?? 0);
                $available       = max(0, $batchItem->planned_quantity - $produced);

                // Sum of quantities already registered in other defect documents for this batch item
                $alreadyDefected = (int) DefectDocumentItem::where('production_batch_item_id', $batchItemId)
                    ->sum('quantity');

                $remaining = max(0, $available - $alreadyDefected);

                if ($quantity > $remaining) {
                    $validator->errors()->add(
                        "items.{$index}.quantity",
                        "Nuxson miqdori ({$quantity}) ruxsat etilgan chegaradan ({$remaining}) oshib ketdi. "
                        . "Reja: {$batchItem->planned_quantity}, Tayor: {$produced}, Avvalgi nuxson: {$alreadyDefected}.",
                    );
                }
            }
        });
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
