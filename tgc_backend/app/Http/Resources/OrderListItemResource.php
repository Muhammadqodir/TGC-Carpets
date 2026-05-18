<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Lightweight order-item resource used only by the orders list endpoint.
 *
 * Differences from OrderItemResource:
 *  - No stock_available  (requires 2 DB queries per item; not shown in the list UI)
 *  - No shipped_quantity (not shown in the list UI)
 *  - No product/color/quality/type tree (only productSize needed for m² calculation)
 *
 * All quantity aggregates are computed from already-eager-loaded collections,
 * so this resource issues zero additional database queries.
 */
class OrderListItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $plannedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems
                ->filter(fn ($pbi) => $pbi->relationLoaded('productionBatch')
                    ? $pbi->productionBatch->status !== 'cancelled'
                    : true)
                ->sum('planned_quantity');
        }, 0);

        $producedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems->sum('produced_quantity');
        }, 0);

        $warehouseReceivedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems->sum('warehouse_received_quantity');
        }, 0);

        $defectQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems->sum('defect_quantity');
        }, 0);

        return [
            'id'                          => $this->id,
            'quantity'                    => $this->quantity,
            'planned_quantity'            => $plannedQty,
            'produced_quantity'           => $producedQty,
            'warehouse_received_quantity' => $warehouseReceivedQty,
            'remaining_quantity'          => max(0, $this->quantity - $plannedQty + $defectQty),
            'variant' => $this->whenLoaded('variant', fn () => [
                'id'           => $this->variant->id,
                'product_size' => $this->variant->relationLoaded('productSize') && $this->variant->productSize
                    ? [
                        'id'     => $this->variant->productSize->id,
                        'length' => $this->variant->productSize->length,
                        'width'  => $this->variant->productSize->width,
                    ]
                    : null,
            ]),
        ];
    }
}
