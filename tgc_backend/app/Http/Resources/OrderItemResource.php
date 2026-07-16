<?php

namespace App\Http\Resources;

use App\Models\StockMovement;
use App\Models\StockReservation;
use App\Models\WarehouseDocument;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // Calculate how much of this item is already planned in non-cancelled batches.
        // Only exclude cancelled batches from planning (future items).
        $plannedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems
                ->filter(fn ($pbi) => $pbi->relationLoaded('productionBatch')
                    ? $pbi->productionBatch->status !== 'cancelled'
                    : true)
                ->sum('planned_quantity');
        }, 0);

        $shippedQty = $this->whenLoaded('shipmentItems', function () {
            return (int) $this->shipmentItems->sum('quantity');
        }, 0);

        // Include ALL produced items, even from cancelled batches.
        // These are physical items that exist and should be accounted for.
        $producedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems->sum('produced_quantity');
        }, 0);

        // Include ALL warehouse-received items, even from cancelled batches.
        // These are physical items in the warehouse.
        $warehouseReceivedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems->sum('warehouse_received_quantity');
        }, 0);

        // Include ALL defects, even from cancelled batches.
        // These are physical defective items that were produced.
        $defectQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems->sum('defect_quantity');
        }, 0);

        // Calculate current warehouse stock for this variant
        $stockAvailable = $this->whenLoaded('variant', function () {
            return $this->getStockForVariant($this->variant->id);
        }, 0);

        // The real reservation claim on this variant — see
        // instructions/phase-3/07-stock-reservations.md. `stock_available`
        // above is physical stock only (its name predates this file and is
        // kept as-is rather than silently redefined — the most dangerous
        // kind of API change); this is the new, additive field: what a
        // client can actually be promised right now.
        $activeReservations = $this->whenLoaded('variant', function () {
            return (int) StockReservation::where('product_variant_id', $this->variant->id)
                ->where('status', StockReservation::STATUS_ACTIVE)
                ->sum('quantity');
        }, 0);

        return [
            'id'                          => $this->id,
            'quantity'                    => $this->quantity,
            'planned_quantity'            => $plannedQty,
            'produced_quantity'           => $producedQty,
            'shipped_quantity'            => $shippedQty,
            'warehouse_received_quantity' => $warehouseReceivedQty,
            'remaining_quantity'          => max(0, $this->quantity - $plannedQty + $defectQty),
            'stock_available'             => $stockAvailable,
            'quantity_active_reservations' => $activeReservations,
            'quantity_available'            => $stockAvailable - $activeReservations,
            'variant'  => $this->whenLoaded('variant', fn () => [
                'id'            => $this->variant->id,
                'barcode_value' => $this->variant->barcode_value,
                'sku_code'      => $this->variant->sku_code,
                'product_color' => $this->variant->relationLoaded('productColor') && $this->variant->productColor
                    ? [
                        'id'        => $this->variant->productColor->id,
                        'image_url' => $this->variant->productColor->image
                            ? Storage::disk('public')->url($this->variant->productColor->image)
                            : null,
                        'color' => $this->variant->productColor->relationLoaded('color') && $this->variant->productColor->color
                            ? ['id' => $this->variant->productColor->color->id, 'name' => $this->variant->productColor->color->name]
                            : null,
                        'product' => $this->variant->productColor->relationLoaded('product') && $this->variant->productColor->product
                            ? [
                                'id'              => $this->variant->productColor->product->id,
                                'name'            => $this->variant->productColor->product->name,
                                'unit'            => $this->variant->productColor->product->unit,
                                'product_type_id' => $this->variant->productColor->product->product_type_id,
                                'product_type'    => $this->variant->productColor->product->relationLoaded('productType') && $this->variant->productColor->product->productType
                                    ? [
                                        'id'   => $this->variant->productColor->product->productType->id,
                                        'type' => $this->variant->productColor->product->productType->type,
                                      ]
                                    : null,
                                'quality_name'    => $this->variant->productColor->product->relationLoaded('productQuality') && $this->variant->productColor->product->productQuality
                                    ? $this->variant->productColor->product->productQuality->quality_name
                                    : null,
                            ]
                            : null,
                    ]
                    : null,
                'product_size' => $this->variant->relationLoaded('productSize') && $this->variant->productSize
                    ? [
                        'id'     => $this->variant->productSize->id,
                        'length' => $this->variant->productSize->length,
                        'width'  => $this->variant->productSize->width,
                    ]
                    : null,
                'product_edge' => $this->variant->relationLoaded('productEdge') && $this->variant->productEdge
                    ? [
                        'id'    => $this->variant->productEdge->id,
                        'code'  => $this->variant->productEdge->code,
                        'title' => $this->variant->productEdge->title,
                    ]
                    : null,
            ]),
        ];
    }

    /**
     * Calculate available warehouse stock for a variant.
     * Uses the same logic as ShipmentService::getStock.
     */
    private function getStockForVariant(int $variantId): int
    {
        $base = StockMovement::where('product_variant_id', $variantId);

        $in = (clone $base)
            ->where('movement_type', StockMovement::TYPE_IN)
            ->sum('quantity');

        $out = (clone $base)
            ->where('movement_type', StockMovement::TYPE_OUT)
            ->sum('quantity');

        return (int) ($in - $out);
    }
}
