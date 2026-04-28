<?php

namespace App\Http\Resources;

use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // Calculate how much of this item is already planned in non-cancelled batches.
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

        $producedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems
                ->filter(fn ($pbi) => $pbi->relationLoaded('productionBatch')
                    ? $pbi->productionBatch->status !== 'cancelled'
                    : true)
                ->sum('produced_quantity');
        }, 0);

        $warehouseReceivedQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems
                ->filter(fn ($pbi) => $pbi->relationLoaded('productionBatch')
                    ? $pbi->productionBatch->status !== 'cancelled'
                    : true)
                ->sum('warehouse_received_quantity');
        }, 0);

        // Defective items must be re-produced, so they count toward remaining.
        $defectQty = $this->whenLoaded('productionBatchItems', function () {
            return (int) $this->productionBatchItems
                ->filter(fn ($pbi) => $pbi->relationLoaded('productionBatch')
                    ? $pbi->productionBatch->status !== 'cancelled'
                    : true)
                ->sum('defect_quantity');
        }, 0);

        // Calculate current warehouse stock for this variant
        $stockAvailable = $this->whenLoaded('variant', function () {
            return $this->getStockForVariant($this->variant->id);
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
            ->whereIn('movement_type', [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN])
            ->sum('quantity');

        $out = (clone $base)
            ->where('movement_type', WarehouseDocument::TYPE_OUT)
            ->sum('quantity');

        return (int) ($in - $out);
    }
}
