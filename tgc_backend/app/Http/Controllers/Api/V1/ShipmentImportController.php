<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProductionBatchItem;
use App\Models\ProductionUnit;
use App\Models\ProductVariant;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

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

    /**
     * Inline subquery: shipped quantity per order_item.
     *
     * Cancelled shipments are excluded: their goods came back, so the order
     * line is owed again and must show up as shippable here.
     */
    private const SHIPPED_SUB = '(SELECT si.order_item_id, COALESCE(SUM(si.quantity), 0) AS shipped_qty
        FROM shipment_items si
        JOIN shipments s ON s.id = si.shipment_id
        WHERE s.canceled_at IS NULL
        GROUP BY si.order_item_id)';

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
            // A cancelled order owes nothing, however much it never shipped —
            // including the auto-order of a cancelled scanned shipment — and
            // nor does one closed as delivered outside the system
            // (OrderService::markDelivered).
            ->whereNotIn('o.status', [\App\Models\Order::STATUS_CANCELED, \App\Models\Order::STATUS_SHIPPED])
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
            // A cancelled order owes nothing, however much it never shipped —
            // including the auto-order of a cancelled scanned shipment — and
            // nor does one closed as delivered outside the system
            // (OrderService::markDelivered).
            ->whereNotIn('o.status', [\App\Models\Order::STATUS_CANCELED, \App\Models\Order::STATUS_SHIPPED])
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
            // A cancelled order owes nothing, however much it never shipped —
            // including the auto-order of a cancelled scanned shipment — and
            // nor does one closed as delivered outside the system
            // (OrderService::markDelivered).
            ->whereNotIn('o.status', [\App\Models\Order::STATUS_CANCELED, \App\Models\Order::STATUS_SHIPPED])
            ->whereRaw('sm.stock > 0')
            ->select([
                'oi.id AS order_item_id',
                'o.id AS order_id',
                'o.order_date',
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
                DB::raw('(oi.quantity - COALESCE(si.shipped_qty, 0)) AS order_remaining'),
            ])
            ->orderBy('p.name')
            ->orderBy('co.name')
            ->orderBy('ps.width')
            ->orderBy('ps.length')
            ->get();

        return response()->json([
            'data' => $rows->map(fn ($r) => [
                'order_item_id'      => $r->order_item_id,
                'order_id'           => (int) $r->order_id,
                'order_date'         => $r->order_date ? substr((string) $r->order_date, 0, 10) : null,
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
                // What the order line still owes, apart from stock: past this
                // the app warns "beyond the order" (see splitOverOrderedLines).
                'order_remaining'    => (int) $r->order_remaining,
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
     *
     * `in_form` (optional, since September 2026) is what the shipment form
     * already carries, as {order_item_id: quantity}. A line whose unshipped
     * quantity is already all on the form is skipped, so scanning the next
     * identical carpet lands on the client's next open line instead of
     * stopping at "limit reached" — and once every open line is full, the
     * carpet comes back `unmatched` (reason `open_lines_full`) for the same
     * "add anyway" flow as a carpet the client never ordered. Builds that do
     * not send it resolve exactly as before.
     */
    public function scan(Request $request): JsonResponse
    {
        $this->recoverScanInput($request);

        $missing = $this->missingScanInput($request);
        if ($missing !== null) {
            return $missing;
        }

        $request->validate([
            'code'      => ['required', 'string'],
            'client_id' => ['required', 'integer', 'exists:clients,id'],
            'in_form'   => ['sometimes', 'array'],
            'in_form.*' => ['integer', 'min:0'],
        ]);

        $code = trim((string) $request->input('code'));
        $clientId = $request->integer('client_id');
        $inForm = $this->inFormQuantities($request->input('in_form'));

        $scanned = $this->resolveVariantFromCode($code);
        if (! $scanned) {
            // 422, not 404: prod's nginx replaces every upstream 404 body with
            // its own HTML page (fastcgi_intercept_errors + error_page 404), so
            // a 404 reached the worker as "404 Not Found nginx". The key is
            // `label`, not `code` — the app retries silently on a `code` error,
            // which means "the request lost its input", not "unknown label".
            return response()->json([
                'message' => 'Mahsulot topilmadi.',
                'errors'  => ['label' => [
                    "Bu QR kod bo'yicha mahsulot topilmadi. Yorliq eski yoki shikastlangan bo'lishi mumkin.",
                ]],
            ], 422);
        }

        $variantId = $scanned['variant_id'];
        $preferredOrderItemId = $scanned['source_order_item_id'];

        $openLines = DB::table('order_items AS oi')
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
            // A cancelled order owes nothing, however much it never shipped —
            // including the auto-order of a cancelled scanned shipment — and
            // nor does one closed as delivered outside the system
            // (OrderService::markDelivered).
            ->whereNotIn('o.status', [\App\Models\Order::STATUS_CANCELED, \App\Models\Order::STATUS_SHIPPED])
            ->select([
                'oi.id AS order_item_id',
                'o.id AS order_id',
                'o.order_date',
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
            ->get();

        // The first open line the form has not already filled. A client
        // rarely has more than a line or two per variant, so this is cheaper
        // to decide here than to express as SQL over the posted map.
        $row = $openLines->first(
            fn ($line) => (int) $line->available_quantity > ($inForm[(int) $line->order_item_id] ?? 0)
        );

        // Name the client the carpet was produced for when the label carries
        // that link and it is not this one: "wrong client selected on the
        // form" is the common case, and the worker can act on it only if told
        // who. Also decides, on both branches below, whether the app asks for
        // confirmation before taking the carpet off that client's order.
        $producedFor = $this->producedForOtherClient($preferredOrderItemId, $clientId);

        if (! $row) {
            $linesFull = $openLines->isNotEmpty();

            $message = $linesFull
                ? "\"{$scanned['product_name']}\" bo'yicha ushbu mijozning ochiq buyurtmasi to'liq yuk xatiga qo'shilgan."
                : "\"{$scanned['product_name']}\" uchun ushbu mijozda ochiq buyurtma topilmadi.";
            if ($producedFor) {
                $message .= " Bu mahsulot \"{$producedFor}\" buyurtmasi uchun ishlab chiqarilgan.";
            }

            // The "add anyway" payload needs every descriptive field a matched
            // row carries — carried here so the sheet costs no second round
            // trip.
            $unmatched = $this->describeVariant(
                $variantId,
                $producedFor,
                $scanned['production_batch_item_id'] ?? null,
            );
            if ($unmatched !== null) {
                // Tells the sheet which sentence is true: the client never
                // ordered this carpet, or ordered it and every one of those
                // is already on the lorry.
                $unmatched['reason'] = $linesFull ? 'open_lines_full' : 'no_open_line';
                $unmatched['client_open_remaining'] = (int) $openLines->sum('available_quantity');
            }

            if ($unmatched === null) {
                return response()->json(['message' => $message], 422);
            }

            // A 200 with the carpet under `data` (order_item_id null), not
            // the 404 this used to be. Prod's nginx swapped that 404 body for
            // its own HTML page, so from 1.3.4 on the "add anyway" sheet never
            // opened and the worker saw "404 Not Found nginx" (2026-10-19 log).
            // Apps since 1.3.4 already read a null order_item_id under `data`
            // as "ask, then add anyway", so this needs no app release.
            // `unmatched` and `message` stay for any client reading them.
            return response()->json([
                'data'      => $unmatched,
                'matched'   => false,
                'message'   => $message,
                'unmatched' => $unmatched,
            ]);
        }

        return response()->json([
            'matched' => true,
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
                'order_remaining'    => (int) $row->available_quantity,
                // Which order this row is, so several rows of the same carpet
                // read as several orders rather than as duplicates.
                'order_id'           => (int) $row->order_id,
                'order_date'         => $row->order_date ? substr((string) $row->order_date, 0, 10) : null,
                // Everything this client still owes for this carpet across
                // all their open orders. Only past THIS is a carpet beyond
                // the order; past one line it just spills onto the next.
                'client_open_remaining' => (int) $openLines->sum('available_quantity'),
                'stock_quantity'     => (int) $row->stock_quantity,
                // Both new in August 2026. The batch item id comes back so
                // the shipment can move the production record with the carpet
                // when it is saved; produced_for_client is non-null only when
                // that move would take the carpet off somebody else's order,
                // which is when the app stops and asks.
                'production_batch_item_id' => $scanned['production_batch_item_id'] ?? null,
                'produced_for_client'      => $producedFor,
            ],
        ]);
    }

    /**
     * Salvages `code`/`client_id`/`in_form` from a body Laravel could not
     * read, before validation reports them missing.
     *
     * Laravel decodes a JSON body with a plain json_decode(): one invalid
     * UTF-8 byte, or a form-encoded body labelled as JSON, and the whole body
     * reads as empty — which surfaced on the factory floor as "The code field
     * is required. (and 1 more error)" for a request that did carry both.
     * Values already present (from the query string, which the app now sends
     * as well) always win; this only fills gaps.
     */
    private function recoverScanInput(Request $request): void
    {
        if ($request->filled('code') && $request->filled('client_id')) {
            return;
        }

        $raw = (string) $request->getContent();
        if ($raw === '') {
            return;
        }

        $decoded = json_decode($raw, true, 512, JSON_INVALID_UTF8_SUBSTITUTE);
        if (! is_array($decoded)) {
            parse_str($raw, $decoded);
        }

        $recovered = [];
        foreach (['code', 'client_id', 'in_form'] as $key) {
            $value = $decoded[$key] ?? null;
            if ($value !== null && $value !== '' && ! $request->filled($key)) {
                $recovered[$key] = is_string($value) ? trim($value) : $value;
            }
        }

        if ($recovered !== []) {
            Log::warning('shipment.scan.input_recovered', [
                'user_id'      => $request->user()?->id,
                'recovered'    => array_keys($recovered),
                'content_type' => $request->header('Content-Type'),
            ]);
            $request->merge($recovered);
        }
    }

    /**
     * The 422 for a scan that reached the server without its code or client,
     * in words a worker can act on, and with enough logged to name the cause.
     *
     * Laravel's own "The code field is required. (and 1 more error)" told the
     * worker nothing and left no trace server-side. The log entry keeps the
     * shape of what did arrive — never the body itself beyond a short prefix,
     * which is a label code, not client data.
     */
    private function missingScanInput(Request $request): ?JsonResponse
    {
        $errors = [];
        if (! $request->filled('code')) {
            $errors['code'] = ["QR kod bo'sh o'qildi yoki serverga yetib kelmadi."];
        }
        if (! $request->filled('client_id')) {
            $errors['client_id'] = ["Mijoz serverga yetib kelmadi."];
        }

        if ($errors === []) {
            return null;
        }

        $raw = (string) $request->getContent();
        Log::warning('shipment.scan.missing_input', [
            'user_id'        => $request->user()?->id,
            'missing'        => array_keys($errors),
            'method'         => $request->method(),
            'content_type'   => $request->header('Content-Type'),
            'content_length' => $request->header('Content-Length'),
            'transfer_enc'   => $request->header('Transfer-Encoding'),
            'body_bytes'     => strlen($raw),
            'body_prefix'    => bin2hex(substr($raw, 0, 64)),
            'query_keys'     => array_keys($request->query()),
            'user_agent'     => $request->userAgent(),
        ]);

        return response()->json([
            'message' => "So'rov serverga to'liq yetib kelmadi. Qayta skanerlang.",
            'errors'  => $errors,
        ], 422);
    }

    /**
     * `in_form` as validated ints, {order_item_id: quantity}. JSON object
     * keys arrive as strings, and anything that is not a positive id is
     * dropped rather than rejected: this map only steers which line is
     * suggested, the submit re-checks everything.
     *
     * @return array<int, int>
     */
    private function inFormQuantities(mixed $inForm): array
    {
        if (! is_array($inForm)) {
            return [];
        }

        $quantities = [];
        foreach ($inForm as $orderItemId => $quantity) {
            if (filter_var($orderItemId, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]) === false) {
                continue;
            }
            $quantities[(int) $orderItemId] = max(0, (int) $quantity);
        }

        return $quantities;
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
    private function describeVariant(
        int $variantId,
        ?string $producedFor,
        ?int $productionBatchItemId = null,
    ): ?array {
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
            // Null for the `PB{n} VAR{n}` label shape, which names a variant
            // and no particular carpet — there is no production row to move.
            'production_batch_item_id' => $productionBatchItemId,
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
                'variant_id'               => $variant->id,
                'source_order_item_id'     => null,
                'production_batch_item_id' => null,
                'product_name'             => (string) $variant->productColor?->product?->name,
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
            'variant_id'               => (int) $item->product_variant_id,
            'source_order_item_id'     => $item->source_order_item_id,
            'production_batch_item_id' => (int) $item->id,
            'product_name'             => (string) $item->variant?->productColor?->product?->name,
        ];
    }

    /**
     * The shop name of the client this carpet was produced for, but only when
     * that is somebody other than [$clientId].
     *
     * This is the fact the whole "add anyway" flow turns on. It reaches the
     * app in both halves of a scan result — matched and unmatched — because
     * shipping someone else's carpet has the same consequence either way:
     * their order stops being ready and the factory owes them a replacement
     * (ShipmentService::reattributeScannedProduction). Null means nobody is
     * losing a carpet: it is this client's own, or it was made for stock.
     */
    private function producedForOtherClient(?int $sourceOrderItemId, int $clientId): ?string
    {
        if ($sourceOrderItemId === null) {
            return null;
        }

        return DB::table('order_items AS oi')
            ->join('orders AS o', 'o.id', '=', 'oi.order_id')
            ->join('clients AS c', 'c.id', '=', 'o.client_id')
            ->where('oi.id', $sourceOrderItemId)
            ->where('o.client_id', '!=', $clientId)
            ->value('c.shop_name');
    }
}
