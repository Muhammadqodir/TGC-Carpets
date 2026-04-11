<?php

namespace App\Http\Requests\Production;

use App\Models\ProductionBatch;
use App\Models\ProductionBatchItem;
use Illuminate\Foundation\Http\FormRequest;

class UpdateProductionBatchRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'batch_title'      => ['sometimes', 'string', 'max:255'],
            'machine_id'       => ['sometimes', 'integer', 'exists:machines,id'],
            'planned_datetime' => ['nullable', 'date'],
            'type'             => ['sometimes', 'string', 'in:' . implode(',', ProductionBatch::TYPES)],
            'notes'            => ['nullable', 'string', 'max:2000'],

            'items'                          => ['sometimes', 'array'],
            'items.*.source_type'            => ['sometimes', 'string', 'in:' . implode(',', ProductionBatchItem::SOURCE_TYPES)],
            'items.*.source_order_item_id'   => ['nullable', 'integer', 'exists:order_items,id'],
            'items.*.product_variant_id'     => ['nullable', 'integer', 'exists:product_variants,id'],
            'items.*.product_color_id'       => ['nullable', 'integer', 'exists:product_colors,id'],
            'items.*.product_size_id'        => ['nullable', 'integer', 'exists:product_sizes,id'],
            'items.*.planned_quantity'       => ['required_with:items', 'integer', 'min:1'],
            'items.*.notes'                  => ['nullable', 'string', 'max:1000'],
        ];
    }
}
