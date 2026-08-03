<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Provides three step-by-step endpoints used by the shipment
 * "import from stock" wizard:
 *
 *   1. GET /shipment-import/clients   – clients with stock-available order items
 *   2. GET /shipment-import/qualities – qualities for a given client
 *   3. GET /shipment-import/items     – shippable items for a given client + quality
 *
 * "Shippable" means: (order_qty - shipped_qty) > 0 AND stock_qty > 0.
 * available_quantity = min(order_qty - shipped_qty, stock_qty).
 */
class ShipmentImportController extends Controller
{
    // ── Shared subquery fragments ──────────────────────────────────────────────

    /** Inline subquery: shipped quantity per order_item. */
    private const SHIPPED_SUB = '(SELECT order_item_id, COALESCE(SUM(quantity), 0) AS shipped_qty
        FROM shipment_items GROUP BY order_item_id)';

    /** Inline subquery: current stock per product_variant. */
    private const STOCK_SUB = '(SELECT product_variant_id,
        COALESCE(SUM(CASE WHEN movement_type = \'in\' THEN quantity ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN movement_type = \'out\' THEN quantity ELSE 0 END), 0) AS stock
        FROM stock_movements GROUP BY product_variant_id)';

    // ── Step 1: Clients ────────────────────────────────────────────────────────

    /**
     * GET /shipment-import/clients
     *
     * Returns all clients that have at least one shippable order item.
     * Response shape: { data: [{ id, shop_name, region, contact_name, item_count }] }
     */
    public function clients(): JsonResponse
    {
        $rows = DB::table('order_items AS oi')
            ->join('orders AS o', 'o.id', '=', 'oi.order_id')
            ->join('clients AS c', 'c.id', '=', 'o.client_id')
            ->leftJoin(DB::raw(self::SHIPPED_SUB . ' AS si'), 'si.order_item_id', '=', 'oi.id')
            ->join(DB::raw(self::STOCK_SUB . ' AS sm'), 'sm.product_variant_id', '=', 'oi.product_variant_id')
            ->whereRaw('(oi.quantity - COALESCE(si.shipped_qty, 0)) > 0')
            ->whereRaw('sm.stock > 0')
            ->select([
                'c.id',
                'c.shop_name',
                'c.region',
                'c.contact_name',
                DB::raw('COUNT(oi.id) AS item_count'),
            ])
            ->groupBy('c.id', 'c.shop_name', 'c.region', 'c.contact_name')
            ->orderBy('c.shop_name')
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
     * GET /shipment-import/qualities?client_id={id}
     *
     * Returns distinct quality names (and item counts) for the given client.
     * Response shape: { data: [{ quality_name, item_count }] }
     */
    public function qualities(Request $request): JsonResponse
    {
        $request->validate(['client_id' => 'required|integer|exists:clients,id']);

        $rows = DB::table('order_items AS oi')
            ->join('orders AS o', 'o.id', '=', 'oi.order_id')
            ->join('product_variants AS pv', 'pv.id', '=', 'oi.product_variant_id')
            ->join('product_colors AS pc', 'pc.id', '=', 'pv.product_color_id')
            ->join('products AS p', 'p.id', '=', 'pc.product_id')
            ->join('product_qualities AS pq', 'pq.id', '=', 'p.product_quality_id')
            ->leftJoin(DB::raw(self::SHIPPED_SUB . ' AS si'), 'si.order_item_id', '=', 'oi.id')
            ->join(DB::raw(self::STOCK_SUB . ' AS sm'), 'sm.product_variant_id', '=', 'oi.product_variant_id')
            ->where('o.client_id', $request->integer('client_id'))
            ->whereRaw('(oi.quantity - COALESCE(si.shipped_qty, 0)) > 0')
            ->whereRaw('sm.stock > 0')
            ->select([
                'pq.quality_name',
                DB::raw('COUNT(oi.id) AS item_count'),
            ])
            ->groupBy('pq.quality_name')
            ->orderBy('pq.quality_name')
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
     * GET /shipment-import/items?client_id={id}&quality_name={name}
     *
     * Returns all shippable items for the given client + quality.
     * available_quantity = min(order_qty - shipped_qty, stock_qty).
     * Response shape: { data: [{ order_item_id, variant_id, product_name, ... }] }
     */
    public function items(Request $request): JsonResponse
    {
        $request->validate([
            'client_id'    => 'required|integer|exists:clients,id',
            'quality_name' => 'required|string',
        ]);

        $rows = DB::table('order_items AS oi')
            ->join('orders AS o', 'o.id', '=', 'oi.order_id')
            ->join('product_variants AS pv', 'pv.id', '=', 'oi.product_variant_id')
            ->join('product_colors AS pc', 'pc.id', '=', 'pv.product_color_id')
            ->join('products AS p', 'p.id', '=', 'pc.product_id')
            ->join('product_qualities AS pq', 'pq.id', '=', 'p.product_quality_id')
            ->leftJoin('colors AS co', 'co.id', '=', 'pc.color_id')
            ->leftJoin('product_sizes AS ps', 'ps.id', '=', 'pv.product_size_id')
            ->leftJoin('product_types AS pt', 'pt.id', '=', 'p.product_type_id')
            ->leftJoin('product_edges AS pe', 'pe.id', '=', 'pv.product_edge_id')
            ->leftJoin(DB::raw(self::SHIPPED_SUB . ' AS si'), 'si.order_item_id', '=', 'oi.id')
            ->join(DB::raw(self::STOCK_SUB . ' AS sm'), 'sm.product_variant_id', '=', 'oi.product_variant_id')
            ->where('o.client_id', $request->integer('client_id'))
            ->where('pq.quality_name', $request->string('quality_name'))
            ->whereRaw('(oi.quantity - COALESCE(si.shipped_qty, 0)) > 0')
            ->whereRaw('sm.stock > 0')
            ->select([
                'oi.id AS order_item_id',
                'pv.id AS variant_id',
                'p.name AS product_name',
                'co.name AS color_name',
                'p.unit AS product_unit',
                'pq.quality_name',
                'pt.type AS type_name',
                'ps.length AS size_length',
                'ps.width AS size_width',
                'pe.code AS edge_code',
                'pe.title AS edge_title',
                DB::raw('LEAST(oi.quantity - COALESCE(si.shipped_qty, 0), sm.stock) AS available_quantity'),
            ])
            ->orderBy('p.name')
            ->orderBy('co.name')
            ->orderBy('ps.width')
            ->orderBy('ps.length')
            ->get();

        return response()->json([
            'data' => $rows->map(fn ($r) => [
                'order_item_id'      => $r->order_item_id,
                'variant_id'         => $r->variant_id,
                'product_name'       => $r->product_name,
                'color_name'         => $r->color_name,
                'color_image_url'    => null,
                'quality_name'       => $r->quality_name,
                'type_name'          => $r->type_name,
                'size_length'        => $r->size_length !== null ? (int) $r->size_length : null,
                'size_width'         => $r->size_width !== null ? (int) $r->size_width : null,
                'product_unit'       => $r->product_unit,
                'edge_code'          => $r->edge_code,
                'edge_title'         => $r->edge_title,
                'available_quantity' => (int) $r->available_quantity,
            ]),
        ]);
    }

    // ── QR scan: resolve a label to a shippable item for a given client ────────

    /**
     * GET /shipment-import/scan?code={code}&client_id={id}
     *
     * Resolves the QR code printed on a production label (the three formats
     * listed on resolveVariantFromCode()) to a shippable order item for the
     * given client, in the same shape as items() above, so it can be dropped
     * straight into the shipment form.
     *
     * The scanned label identifies a product_variant, not an order item by
     * itself, so resolution picks — among this client's open order items for
     * that variant — the one the carpet was actually produced for
     * (source_order_item_id) when that is still shippable, otherwise the
     * oldest open order item (FIFO). This is a convenience lookup only: the
     * authoritative checks (over-shipping, variant/order mismatch, client
     * ownership) still run in StoreShipmentRequest when the shipment is
     * actually submitted.
     *
     * Unlike items() — the stock wizard, which is *about* picking from stock —
     * this lookup deliberately does NOT require stock_movements to exist for
     * the variant. The worker is standing in front of the physical carpet with
     * its label in hand; whether it was ever booked into the warehouse is a
     * separate bookkeeping question, and gating on it made 5,457 of prod's
     * 5,929 batch items unscannable (2026-08-03 field test). Stock still rides
     * along in the response as `stock_quantity` for information.
     */
    public function scan(Request $request): JsonResponse
    {
        $request->validate([
            'code'      => ['required', 'string'],
            'client_id' => ['required', 'integer', 'exists:clients,id'],
        ]);

        $code = trim((string) $request->input('code'));
        $clientId = $request->integer('client_id');

        $scanned = $this->resolveVariantFromCode($code);
        if (! $scanned) {
            return response()->json(['message' => 'Mahsulot topilmadi.'], 404);
        }

        $variantId = $scanned['variant_id'];
        $preferredOrderItemId = $scanned['source_order_item_id'];

        $row = DB::table('order_items AS oi')
            ->join('orders AS o', 'o.id', '=', 'oi.order_id')
            ->join('product_variants AS pv', 'pv.id', '=', 'oi.product_variant_id')
            ->join('product_colors AS pc', 'pc.id', '=', 'pv.product_color_id')
            ->join('products AS p', 'p.id', '=', 'pc.product_id')
            ->join('product_qualities AS pq', 'pq.id', '=', 'p.product_quality_id')
            ->leftJoin('colors AS co', 'co.id', '=', 'pc.color_id')
            ->leftJoin('product_sizes AS ps', 'ps.id', '=', 'pv.product_size_id')
            ->leftJoin('product_types AS pt', 'pt.id', '=', 'p.product_type_id')
            ->leftJoin('product_edges AS pe', 'pe.id', '=', 'pv.product_edge_id')
            ->leftJoin(DB::raw(self::SHIPPED_SUB . ' AS si'), 'si.order_item_id', '=', 'oi.id')
            ->leftJoin(DB::raw(self::STOCK_SUB . ' AS sm'), 'sm.product_variant_id', '=', 'oi.product_variant_id')
            ->where('o.client_id', $clientId)
            ->where('oi.product_variant_id', $variantId)
            ->whereRaw('(oi.quantity - COALESCE(si.shipped_qty, 0)) > 0')
            ->select([
                'oi.id AS order_item_id',
                'pv.id AS variant_id',
                'p.name AS product_name',
                'co.name AS color_name',
                'pc.image AS color_image',
                'p.unit AS product_unit',
                'pq.quality_name',
                'pt.type AS type_name',
                'ps.length AS size_length',
                'ps.width AS size_width',
                'pe.code AS edge_code',
                'pe.title AS edge_title',
                // Capped by what is still unshipped on the order line only —
                // see the note on stock in this method's docblock.
                DB::raw('(oi.quantity - COALESCE(si.shipped_qty, 0)) AS available_quantity'),
                DB::raw('COALESCE(sm.stock, 0) AS stock_quantity'),
            ])
            ->orderByRaw('(oi.id = ?) DESC', [$preferredOrderItemId ?? 0])
            ->orderBy('oi.id')
            ->first();

        if (! $row) {
            // Name the client the carpet was produced for when the label
            // carries that link: "wrong client selected on the form" is the
            // common case, and the worker can act on it only if told who.
            $producedFor = $preferredOrderItemId
                ? DB::table('order_items AS oi')
                    ->join('orders AS o', 'o.id', '=', 'oi.order_id')
                    ->join('clients AS c', 'c.id', '=', 'o.client_id')
                    ->where('oi.id', $preferredOrderItemId)
                    ->value('c.shop_name')
                : null;

            $message = "\"{$scanned['product_name']}\" uchun ushbu mijozda ochiq buyurtma topilmadi.";
            if ($producedFor) {
                $message .= " Bu mahsulot \"{$producedFor}\" buyurtmasi uchun ishlab chiqarilgan.";
            }

            // Stays a 404 so the released 1.3.0 build keeps showing `message`
            // exactly as it does today. Newer builds read `unmatched` instead
            // and offer "add anyway", which needs every descriptive field a
            // matched row carries — carried here so the sheet costs no second
            // round trip.
            return response()->json([
                'message'   => $message,
                'unmatched' => $this->describeVariant($variantId, $producedFor),
            ], 404);
        }

        return response()->json([
            'data' => [
                'order_item_id'      => $row->order_item_id,
                'variant_id'         => $row->variant_id,
                'product_name'       => $row->product_name,
                'color_name'         => $row->color_name,
                'color_image_url'    => $row->color_image
                    ? rtrim(config('app.url'), '/') . '/storage/' . $row->color_image
                    : null,
                'quality_name'       => $row->quality_name,
                'type_name'          => $row->type_name,
                'size_length'        => $row->size_length !== null ? (int) $row->size_length : null,
                'size_width'         => $row->size_width !== null ? (int) $row->size_width : null,
                'product_unit'       => $row->product_unit,
                'edge_code'          => $row->edge_code,
                'edge_title'         => $row->edge_title,
                'available_quantity' => (int) $row->available_quantity,
                'stock_quantity'     => (int) $row->stock_quantity,
            ],
        ]);
    }

    /**
     * The descriptive half of a scan result for a variant that resolved but
     * has no shippable order line under the scanned client — same field names
     * as the matched payload above so the client can render one card either
     * way, plus `produced_for_client` for the "this carpet belongs to someone
     * else's order" warning. `order_item_id` is null by definition: creating
     * that line is what "add anyway" does, and it happens at submit time so an
     * abandoned form leaves no orphan order behind.
     */
    private function describeVariant(int $variantId, ?string $producedFor): ?array
    {
        $row = DB::table('product_variants AS pv')
            ->join('product_colors AS pc', 'pc.id', '=', 'pv.product_color_id')
            ->join('products AS p', 'p.id', '=', 'pc.product_id')
            ->join('product_qualities AS pq', 'pq.id', '=', 'p.product_quality_id')
            ->leftJoin('colors AS co', 'co.id', '=', 'pc.color_id')
            ->leftJoin('product_sizes AS ps', 'ps.id', '=', 'pv.product_size_id')
            ->leftJoin('product_types AS pt', 'pt.id', '=', 'p.product_type_id')
            ->leftJoin('product_edges AS pe', 'pe.id', '=', 'pv.product_edge_id')
            ->leftJoin(DB::raw(self::STOCK_SUB . ' AS sm'), 'sm.product_variant_id', '=', 'pv.id')
            ->where('pv.id', $variantId)
            ->select([
                'pv.id AS variant_id',
                'p.name AS product_name',
                'co.name AS color_name',
                'pc.image AS color_image',
                'p.unit AS product_unit',
                'pq.quality_name',
                'pt.type AS type_name',
                'ps.length AS size_length',
                'ps.width AS size_width',
                'pe.code AS edge_code',
                'pe.title AS edge_title',
                DB::raw('COALESCE(sm.stock, 0) AS stock_quantity'),
            ])
            ->first();

        if (! $row) {
            return null;
        }

        return [
            'order_item_id'       => null,
            'variant_id'          => (int) $row->variant_id,
            'product_name'        => $row->product_name,
            'color_name'          => $row->color_name,
            'color_image_url'     => $row->color_image
                ? rtrim(config('app.url'), '/') . '/storage/' . $row->color_image
                : null,
            'quality_name'        => $row->quality_name,
            'type_name'           => $row->type_name,
            'size_length'         => $row->size_length !== null ? (int) $row->size_length : null,
            'size_width'          => $row->size_width !== null ? (int) $row->size_width : null,
            'product_unit'        => $row->product_unit,
            'edge_code'           => $row->edge_code,
            'edge_title'          => $row->edge_title,
            'stock_quantity'      => (int) $row->stock_quantity,
            'produced_for_client' => $producedFor,
        ];
    }

    /**
     * Resolves a scanned label to the product_variant it identifies, plus the
     * order item it was produced for when the label carries that link.
     *
     * Three formats, the first two shared with
     * ProductionBatchController::scanItem() (instructions/phase-0/11 and
     * phase-3/02) — kept as an independent implementation since that endpoint
     * returns a different shape and this one must not affect the production
     * scan flow:
     *
     *   TGC-U-\d{8}                — one printed unit serial
     *   P{batchId} I{itemId}       — a batch line (also spelled PB.. PBI..)
     *   PB{batchId} VAR{variantId} — the print-history fallback for entries
     *                                saved before the item id was recorded
     *
     * That third format is rejected by scanItem() on purpose, because there it
     * must identify one physical carpet and VAR names only the variant. Here
     * the variant is precisely — and all — the lookup needs: resolution then
     * runs through this client's own open order lines, so a label that is
     * vague about *which* carpet still cannot resolve to the wrong client's
     * order. It has no source order item, so the FIFO branch takes over.
     *
     * @return array{variant_id:int, source_order_item_id:int|null, product_name:string}|null
     */
    private function resolveVariantFromCode(string $code): ?array
    {
        if (preg_match('/^TGC-U-\d{8}$/', $code)) {
            $unit = ProductionUnit::where('serial', $code)->first();
            if (! $unit) {
                return null;
            }

            return $this->batchItemPayload(
                ProductionBatchItem::with('variant.productColor.product')
                    ->find($unit->production_batch_item_id)
            );
        }

        if (preg_match('/^P(?:B)?\{?(\d+)\}?\s+(?:PB)?I\{?(\d+)\}?$/i', $code, $matches)) {
            return $this->batchItemPayload(
                ProductionBatchItem::with('variant.productColor.product')
                    ->where('id', (int) $matches[2])
                    ->where('production_batch_id', (int) $matches[1])
                    ->first()
            );
        }

        if (preg_match('/^P(?:B)?\{?\d+\}?\s+VAR\{?(\d+)\}?$/i', $code, $matches)) {
            $variant = ProductVariant::with('productColor.product')
                ->find((int) $matches[1]);

            if (! $variant) {
                return null;
            }

            return [
                'variant_id'           => $variant->id,
                'source_order_item_id' => null,
                'product_name'         => (string) $variant->productColor?->product?->name,
            ];
        }

        return null;
    }

    /** @return array{variant_id:int, source_order_item_id:int|null, product_name:string}|null */
    private function batchItemPayload(?ProductionBatchItem $item): ?array
    {
        if (! $item) {
            return null;
        }

        return [
            'variant_id'           => (int) $item->product_variant_id,
            'source_order_item_id' => $item->source_order_item_id,
            'product_name'         => (string) $item->variant?->productColor?->product?->name,
        ];
    }
}
