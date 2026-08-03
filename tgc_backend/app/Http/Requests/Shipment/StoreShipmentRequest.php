<?php

namespace App\Http\Requests\Shipment;

use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Validator;

class StoreShipmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'client_id'               => ['required', 'integer', 'exists:clients,id'],
            'order_id'                => ['nullable', 'integer', 'exists:orders,id'],
            'shipment_datetime'       => ['required', 'date'],
            'notes'                   => ['nullable', 'string', 'max:2000'],

            // Not required and not yet surfaced by any client build — see
            // instructions/phase-3/04-currency-vat-discount.md. Omitting
            // them defaults to USD / rate 1 / no VAT, i.e. exactly today's
            // behaviour. The currency selector stays hidden in the client
            // until the "How to verify" checklist in that file has been
            // run end to end; sending these fields ahead of that is a
            // developer/API action, not something the app does yet.
            'currency'                => ['nullable', 'string', 'size:3'],
            'exchange_rate'           => ['nullable', 'numeric', 'gt:0'],
            'vat_rate'                => ['nullable', 'numeric', 'min:0', 'max:1'],

            'items'                          => ['required', 'array', 'min:1'],
            // Nullable only for scanned lines — see the `scanned` rule below
            // and the required-unless-scanned check in withValidator().
            'items.*.order_item_id'          => ['nullable', 'integer', 'exists:order_items,id'],
            'items.*.product_variant_id'     => ['required', 'integer', 'exists:product_variants,id'],
            'items.*.quantity'               => ['required', 'integer', 'min:1'],
            'items.*.price'                  => ['required', 'numeric', 'min:0'],
            'items.*.discount_type'          => ['nullable', 'string', 'in:none,percent,amount'],
            'items.*.discount_value'         => ['nullable', 'numeric', 'min:0'],

            // "This line came from scanning the label on a physical carpet the
            // worker is holding." That claim is what licenses the two things
            // ShipmentService does for these lines and no others: creating the
            // missing order line (add anyway), and booking the carpet into the
            // warehouse before shipping it out when it was never received.
            // Lines from the order/stock import wizards never set it, so their
            // behaviour is unchanged.
            'items.*.scanned'                => ['sometimes', 'boolean'],
        ];
    }

    /**
     * Checks that the exists: rules above cannot express: that the posted IDs
     * belong together, not merely that each one resolves. See
     * instructions/phase-1/02-validate-shipment-items.md.
     *
     * Gated behind config('shipments.enforce_item_validation') — log-only
     * until a week of production logs is understood, because the live app
     * may already be posting shipments these checks would reject.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $v) {
            if ($v->errors()->isNotEmpty()) {
                return;   // IDs did not resolve; the checks below would be meaningless
            }

            $violations = [];
            $data       = $v->getData();

            // ── order_item_id is required unless the line was scanned ──────────
            // Enforced here rather than as a rule because required_without does
            // not address a sibling key under the same wildcard index. This one
            // is NOT gated behind enforce_item_validation: a non-scanned line
            // with no order item cannot be written at all (shipment_items.
            // order_item_id is NOT NULL), so accepting it would only turn a
            // clear 422 into a 500.
            foreach ($data['items'] ?? [] as $index => $item) {
                if (($item['order_item_id'] ?? null) === null
                    && ! filter_var($item['scanned'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
                    $v->errors()->add(
                        "items.{$index}.order_item_id",
                        'The order item id field is required for lines that were not scanned.',
                    );
                }
            }

            if ($v->errors()->isNotEmpty()) {
                return;
            }

            // ── Order belongs to client ────────────────────────────────────────
            if (! empty($data['order_id'])) {
                $order = Order::find($data['order_id']);
                if ($order && (int) $order->client_id !== (int) $data['client_id']) {
                    $violations['order_id'] = sprintf(
                        'Order #%d belongs to client #%d, not client #%d.',
                        $order->id, $order->client_id, $data['client_id']
                    );
                }
            }

            // ── Per-item checks ────────────────────────────────────────────────
            // Sum requested quantity per order_item first: two lines against the
            // same order item must be checked against their combined total, not
            // each on its own.
            // Scanned lines with no order item yet are skipped throughout: the
            // order line they will hang off does not exist until
            // ShipmentService creates it, so there is nothing here to check
            // them against. What they do get checked against is stock, in
            // ShipmentService::assertSufficientStock().
            $requestedPerOrderItem = [];
            foreach ($data['items'] ?? [] as $item) {
                if (($item['order_item_id'] ?? null) === null) {
                    continue;
                }
                $id = (int) $item['order_item_id'];
                $requestedPerOrderItem[$id] = ($requestedPerOrderItem[$id] ?? 0) + (int) $item['quantity'];
            }

            $orderItems = OrderItem::with('order')
                ->whereIn('id', array_keys($requestedPerOrderItem))
                ->get()
                ->keyBy('id');

            // Cancelled shipments do not count against the order line: their
            // goods came back, so that quantity is shippable again.
            $shippedPerOrderItem = DB::table('shipment_items as si')
                ->join('shipments as s', 's.id', '=', 'si.shipment_id')
                ->whereNull('s.canceled_at')
                ->whereIn('si.order_item_id', array_keys($requestedPerOrderItem))
                ->groupBy('si.order_item_id')
                ->pluck(DB::raw('COALESCE(SUM(si.quantity), 0)'), 'si.order_item_id');

            foreach ($data['items'] ?? [] as $index => $item) {
                if (($item['order_item_id'] ?? null) === null) {
                    continue;   // scanned line; its order item does not exist yet
                }

                $orderItem = $orderItems->get((int) $item['order_item_id']);
                if (! $orderItem) {
                    continue;   // exists: rule already flagged it
                }

                // order_item belongs to the shipment's order
                if (! empty($data['order_id'])
                    && (int) $orderItem->order_id !== (int) $data['order_id']) {
                    $violations["items.{$index}.order_item_id"] = sprintf(
                        'Order item #%d belongs to order #%d, not order #%d.',
                        $orderItem->id, $orderItem->order_id, $data['order_id']
                    );
                }

                // order_item's order belongs to the billed client
                if ((int) $orderItem->order?->client_id !== (int) $data['client_id']) {
                    $violations["items.{$index}.order_item_id"] = sprintf(
                        'Order item #%d belongs to client #%d, not client #%d.',
                        $orderItem->id, $orderItem->order?->client_id, $data['client_id']
                    );
                }

                // variant matches what was ordered
                if ((int) $orderItem->product_variant_id !== (int) $item['product_variant_id']) {
                    $violations["items.{$index}.product_variant_id"] = sprintf(
                        'Order item #%d is for variant #%d, not variant #%d.',
                        $orderItem->id, $orderItem->product_variant_id, $item['product_variant_id']
                    );
                }
            }

            // ── Over-shipping, checked per order_item across all lines ─────────
            foreach ($requestedPerOrderItem as $orderItemId => $requested) {
                $orderItem = $orderItems->get($orderItemId);
                if (! $orderItem) {
                    continue;
                }

                $shipped   = (int) ($shippedPerOrderItem[$orderItemId] ?? 0);
                $remaining = $orderItem->quantity - $shipped;

                if ($requested > $remaining) {
                    $violations["order_item.{$orderItemId}.quantity"] = sprintf(
                        'Order item #%d: %d requested, only %d unshipped (ordered %d, already shipped %d).',
                        $orderItemId, $requested, max(0, $remaining), $orderItem->quantity, $shipped
                    );
                }
            }

            $this->reportViolations($violations, $v);
        });
    }

    private function reportViolations(array $violations, Validator $v): void
    {
        if ($violations === []) {
            return;
        }

        if (! config('shipments.enforce_item_validation', false)) {
            Log::warning('shipment.validation.would_reject', [
                'user_id'    => $this->user()?->id,
                'client_id'  => $this->input('client_id'),
                'order_id'   => $this->input('order_id'),
                'violations' => $violations,
                'payload'    => $this->except(['notes']),
            ]);

            return;   // request proceeds exactly as it does today
        }

        foreach ($violations as $key => $message) {
            $v->errors()->add($key, $message);
        }
    }
}
