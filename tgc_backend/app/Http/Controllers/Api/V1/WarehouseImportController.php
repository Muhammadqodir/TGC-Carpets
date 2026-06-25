<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductionBatchItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Provides three step-by-step endpoints used by the warehouse
 * "import from production" dialog:
 *
 *   1. GET /warehouse-import/clients   – distinct clients with ready items
 *   2. GET /warehouse-import/qualities – qualities for a given client
 *   3. GET /warehouse-import/items     – items for a given client + quality
 *
 * "Ready" means: source_type = 'order_item' and
 * (produced_quantity - warehouse_received_quantity) > 0.
 */
class WarehouseImportController extends Controller
{
    // ── Shared base query ──────────────────────────────────────────────────────

    /** Returns a query scoped to order-linked items that still have available qty. */
    private function readyItemsQuery()
    {
        return ProductionBatchItem::query()
            ->where('source_type', ProductionBatchItem::SOURCE_ORDER_ITEM)
            ->whereNotNull('source_order_item_id')
            ->whereRaw(
                '(COALESCE(produced_quantity, 0) - COALESCE(warehouse_received_quantity, 0)) > 0'
            );
    }

    // ── Step 1: Clients ────────────────────────────────────────────────────────

    /**
     * GET /warehouse-import/clients
     *
     * Returns all clients that have at least one ready production batch item.
     * Response shape: { data: [{ id, shop_name, region, contact_name, item_count }] }
     */
    public function clients(): JsonResponse
    {
        $rows = $this->readyItemsQuery()
            ->join('order_items', 'order_items.id', '=', 'production_batch_items.source_order_item_id')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('clients', 'clients.id', '=', 'orders.client_id')
            ->select([
                'clients.id',
                'clients.shop_name',
                'clients.region',
                'clients.contact_name',
                DB::raw('COUNT(production_batch_items.id) AS item_count'),
            ])
            ->groupBy('clients.id', 'clients.shop_name', 'clients.region', 'clients.contact_name')
            ->orderBy('clients.shop_name')
            ->get();

        return response()->json([
            'data' => $rows->map(fn ($r) => [
                'id'           => $r->id,
                'shop_name'    => $r->shop_name,
                'region'       => $r->region,
                'contact_name' => $r->contact_name,
                'item_count'   => (int) $r->item_count,
            ]),
        ]);
    }

    // ── Step 2: Qualities ──────────────────────────────────────────────────────

    /**
     * GET /warehouse-import/qualities?client_id={id}
     *
     * Returns distinct quality names (and item counts) for the given client.
     * Response shape: { data: [{ quality_name, item_count }] }
     */
    public function qualities(Request $request): JsonResponse
    {
        $request->validate(['client_id' => 'required|integer|exists:clients,id']);

        $rows = $this->readyItemsQuery()
            ->join('order_items', 'order_items.id', '=', 'production_batch_items.source_order_item_id')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('product_variants', 'product_variants.id', '=', 'production_batch_items.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->join('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->where('orders.client_id', $request->integer('client_id'))
            ->select([
                'product_qualities.quality_name',
                DB::raw('COUNT(production_batch_items.id) AS item_count'),
            ])
            ->groupBy('product_qualities.quality_name')
            ->orderBy('product_qualities.quality_name')
            ->get();

        return response()->json([
            'data' => $rows->map(fn ($r) => [
                'quality_name' => $r->quality_name,
                'item_count'   => (int) $r->item_count,
            ]),
        ]);
    }

    // ── Step 3: Items ──────────────────────────────────────────────────────────

    /**
     * GET /warehouse-import/items?client_id={id}&quality_name={name}
     *
     * Returns all ready items for the given client + quality, with flat fields
     * matching the Flutter ImportItemModel JSON shape.
     */
    public function items(Request $request): JsonResponse
    {
        $request->validate([
            'client_id'    => 'required|integer|exists:clients,id',
            'quality_name' => 'required|string',
        ]);

        $rows = $this->readyItemsQuery()
            ->join('production_batches', 'production_batches.id', '=', 'production_batch_items.production_batch_id')
            ->join('order_items', 'order_items.id', '=', 'production_batch_items.source_order_item_id')
            ->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->join('clients', 'clients.id', '=', 'orders.client_id')
            ->join('product_variants', 'product_variants.id', '=', 'production_batch_items.product_variant_id')
            ->join('product_colors', 'product_colors.id', '=', 'product_variants.product_color_id')
            ->join('products', 'products.id', '=', 'product_colors.product_id')
            ->join('product_qualities', 'product_qualities.id', '=', 'products.product_quality_id')
            ->leftJoin('colors', 'colors.id', '=', 'product_colors.color_id')
            ->leftJoin('product_sizes', 'product_sizes.id', '=', 'product_variants.product_size_id')
            ->leftJoin('product_types', 'product_types.id', '=', 'products.product_type_id')
            ->leftJoin('product_edges', 'product_edges.id', '=', 'product_variants.product_edge_id')
            ->where('orders.client_id', $request->integer('client_id'))
            ->where('product_qualities.quality_name', $request->string('quality_name'))
            ->select([
                'production_batch_items.id',
                'production_batches.id AS batch_id',
                'production_batches.batch_title',
                'production_batch_items.source_type',
                'production_batch_items.planned_quantity',
                'production_batch_items.produced_quantity',
                'production_batch_items.defect_quantity',
                'production_batch_items.warehouse_received_quantity',
                'production_batch_items.notes',
                'order_items.id AS source_order_item_id',
                'orders.id AS source_order_id',
                'order_items.quantity AS source_order_quantity',
                'clients.shop_name AS source_client_shop_name',
                'clients.region AS source_client_region',
                'product_variants.id AS variant_id',
                'product_variants.sku_code AS variant_sku',
                'product_variants.barcode_value AS variant_barcode',
                'products.id AS product_id',
                'products.name AS product_name',
                'products.unit AS product_unit',
                'product_qualities.quality_name',
                'colors.name AS color_name',
                'product_colors.id AS product_color_id',
                'product_sizes.id AS product_size_id',
                'product_sizes.length AS size_length',
                'product_sizes.width AS size_width',
                'product_types.id AS product_type_id',
                'product_types.type AS product_type_name',
                'product_edges.code AS edge_code',
            ])
            ->orderBy('products.name')
            ->orderBy('colors.name')
            ->orderBy('product_sizes.width')
            ->orderBy('product_sizes.length')
            ->get();

        return response()->json([
            'data' => $rows->map(fn ($r) => [
                'id'                          => $r->id,
                'batch_id'                    => $r->batch_id,
                'batch_title'                 => $r->batch_title,
                'source_type'                 => $r->source_type,
                'planned_quantity'            => (int) $r->planned_quantity,
                'produced_quantity'           => $r->produced_quantity !== null ? (int) $r->produced_quantity : null,
                'defect_quantity'             => $r->defect_quantity !== null ? (int) $r->defect_quantity : null,
                'warehouse_received_quantity' => $r->warehouse_received_quantity !== null ? (int) $r->warehouse_received_quantity : null,
                'notes'                       => $r->notes,
                'source_order_item_id'        => $r->source_order_item_id,
                'source_order_id'             => $r->source_order_id,
                'source_order_quantity'       => $r->source_order_quantity !== null ? (int) $r->source_order_quantity : null,
                'source_client_shop_name'     => $r->source_client_shop_name,
                'source_client_region'        => $r->source_client_region,
                'variant_id'                  => $r->variant_id,
                'variant_sku'                 => $r->variant_sku,
                'variant_barcode'             => $r->variant_barcode,
                'product_id'                  => $r->product_id,
                'product_name'                => $r->product_name,
                'product_unit'                => $r->product_unit,
                'quality_name'                => $r->quality_name,
                'color_name'                  => $r->color_name,
                'color_image_url'             => null, // served separately via storage
                'product_color_id'            => $r->product_color_id,
                'product_size_id'             => $r->product_size_id,
                'size_length'                 => $r->size_length !== null ? (int) $r->size_length : null,
                'size_width'                  => $r->size_width !== null ? (int) $r->size_width : null,
                'product_type_id'             => $r->product_type_id,
                'product_type_name'           => $r->product_type_name,
                'edge_code'                   => $r->edge_code,
            ]),
        ]);
    }
}
