<?php

namespace App\Http\Requests\WarehouseDocument;

use App\Models\WarehouseDocument;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreWarehouseDocumentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'external_uuid'         => ['nullable', 'uuid', Rule::unique('warehouse_documents', 'external_uuid')],
            'type'                  => ['required', 'string', Rule::in(WarehouseDocument::TYPES)],
            // Meaningful only for 'adjustment'; WarehouseDocument::resolveMovementType()
            // ignores it for every other type regardless of what is sent.
            //
            // NOT required, deliberately, even though the instruction file's
            // first-pass example makes it so: the live Flutter client does
            // not send this field yet, and requiring it would 422 every
            // adjustment document created from an unreleased client build.
            // A missing direction defaults to 'in' server-side (see
            // WarehouseDocument::resolveMovementType()), which is exactly
            // today's behaviour — safe to ship ahead of the client release.
            // Tighten to required only once client adoption is confirmed.
            // See instructions/phase-3/05-signed-adjustment-documents.md
            // "How to verify" #11 and DEPLOY.md.
            'direction'             => [
                'nullable',
                Rule::in([WarehouseDocument::DIRECTION_IN, WarehouseDocument::DIRECTION_OUT]),
            ],
            'document_date'         => ['required', 'date'],
            'notes'                 => ['nullable', 'string'],

            'items'                       => ['required', 'array', 'min:1'],
            'items.*.product_id'          => ['required', 'integer', 'exists:products,id'],
            'items.*.product_color_id'    => ['required', 'integer', 'exists:product_colors,id'],
            'items.*.product_size_id'     => ['required', 'integer', 'exists:product_sizes,id'],
            'items.*.product_edge_id'     => ['nullable', 'integer', 'exists:product_edges,id'],
            'items.*.quantity'            => ['required', 'integer', 'min:1'],
            'items.*.source_type'         => ['nullable', 'string', Rule::in(['shipment_item', 'production_batch_item'])],
            'items.*.source_id'           => ['nullable', 'integer', 'min:1'],
            'items.*.notes'               => ['nullable', 'string'],
            // Optional, TYPE_IN only — real unit serials scanned at receipt.
            // No client sends this yet. See
            // instructions/phase-3/02-production-units-serials.md §5.
            'items.*.serials'             => ['nullable', 'array'],
            'items.*.serials.*'           => ['string', 'regex:/^TGC-U-\d{8}$/'],
        ];
    }
}
