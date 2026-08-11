<?php

namespace App\Http\Requests\Shipment;

use App\Models\ShipmentItem;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

/**
 * Prices for the lines of an already-created shipment.
 *
 * Shipments are now created without prices — a warehouse worker loading a
 * lorry has no business guessing what the client pays — so this is the
 * request that turns a shipment into money: the office opens it, fills the
 * lines in, and the hisob-faktura is regenerated from what they typed.
 *
 * Only prices. Quantities, variants and order lines are settled when the
 * shipment is created and are not editable here: changing them would mean
 * moving stock, which is what cancelling and re-creating a shipment is for.
 */
class UpdateShipmentPricesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'items'            => ['required', 'array', 'min:1'],
            'items.*.id'       => ['required', 'integer', 'exists:shipment_items,id'],
            'items.*.price'    => ['required', 'numeric', 'min:0'],

            // Accepted for completeness because the stored discount_amount is
            // recomputed from them, but no client build sends them yet — see
            // instructions/phase-3/04-currency-vat-discount.md.
            'items.*.discount_type'  => ['nullable', 'string', 'in:none,percent,amount'],
            'items.*.discount_value' => ['nullable', 'numeric', 'min:0'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $v) {
            if ($v->errors()->isNotEmpty()) {
                return;   // the ids did not resolve; the check below is meaningless
            }

            $shipmentId = $this->route('shipment')->id;

            // `exists:shipment_items,id` proves the line exists, not that it
            // belongs to the shipment in the URL. Without this, a typo (or a
            // stale form) would price somebody else's shipment.
            $foreign = ShipmentItem::whereIn('id', collect($this->input('items'))->pluck('id'))
                ->where('shipment_id', '!=', $shipmentId)
                ->pluck('id');

            foreach ($foreign as $id) {
                $v->errors()->add(
                    'items',
                    "Qator #{$id} bu yuk xatiga tegishli emas.",
                );
            }
        });
    }
}
