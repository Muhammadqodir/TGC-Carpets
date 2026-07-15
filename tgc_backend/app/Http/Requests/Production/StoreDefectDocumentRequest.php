<?php

namespace App\Http\Requests\Production;

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

                $produced          = (int) ($batchItem->produced_quantity ?? 0);
                $defected          = (int) ($batchItem->defect_quantity ?? 0);
                $warehouseReceived = (int) ($batchItem->warehouse_received_quantity ?? 0);

                // Defects may come from EITHER the unproduced remainder OR from
                // produced-but-not-yet-received units (a finished carpet condemned
                // by QC). See instructions/phase-2/05-defect-and-scrap-as-events.md
                // (PROD-4) — the old formula only allowed defects on carpets that
                // were never made, which rejected every defect on a fully labelled
                // batch.
                $unproducedRemainder = max(0, $batchItem->planned_quantity - $produced - $defected);
                $scrappableProduced  = max(0, $produced - $warehouseReceived);

                $remaining = $unproducedRemainder + $scrappableProduced;

                if ($quantity > $remaining) {
                    $validator->errors()->add(
                        "items.{$index}.quantity",
                        "Nuxson miqdori ({$quantity}) ruxsat etilgan chegaradan ({$remaining}) oshib ketdi. "
                        . "Reja: {$batchItem->planned_quantity}, Tayor: {$produced}, "
                        . "Nuxson: {$defected}, Omborda: {$warehouseReceived}.",
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
