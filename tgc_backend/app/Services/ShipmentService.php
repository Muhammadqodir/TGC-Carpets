<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\ProductionBatchItem;
use App\Models\ProductVariant;
use App\Models\Shipment;
use App\Models\ShipmentItem;
use App\Models\StockMovement;
use App\Models\WarehouseDocument;
use App\Models\WarehouseDocumentItem;
use Barryvdh\DomPDF\Facade\Pdf;
use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use PhpOffice\PhpSpreadsheet\Cell\DataType;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Style\Alignment;
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

class ShipmentService
{
    public function __construct(
        private readonly WarehousePdfService $warehousePdfService,
        private readonly ProductVariantStockService $stockService,
        private readonly StockReservationService $reservationService,
    ) {}

    /**
     * Create a shipment, reduce warehouse stock, and update related order status.
     *
     * Flow per item:
     *   1. Give scanned lines that have no order item one to hang off (a single
     *      auto-created order for the whole shipment), and book in any scanned
     *      carpet the warehouse never received.
     *   2. Validate sufficient stock for every variant.
     *   3. Create the Shipment header.
     *   4. Create a WarehouseDocument of type 'out' to represent the outgoing stock.
     *   5. For each item: create ShipmentItem → WarehouseDocumentItem → StockMovement.
     *   6. If the linked order's items are fully shipped, mark the order as 'shipped'.
     *
     * Step 1 exists because a worker scanning labels is looking at carpets that
     * physically exist, which the order and stock tables do not always agree
     * with — the carpet may have been produced against another client's order,
     * or never booked into the warehouse at all. Both are repaired here rather
     * than refused, but ONLY for lines the client marked `scanned`; everything
     * posted by the order/stock import wizards keeps the old strict behaviour.
     */
    public function create(array $data, int $userId): Shipment
    {
        $warehouseDocId = null;

        $shipment = DB::transaction(function () use ($data, $userId, &$warehouseDocId): Shipment {
            $shipmentDate = Carbon::parse($data['shipment_datetime']);

            // ── 0. Repairs for scanned lines, before anything is validated ──
            [$data['items'], $autoOrderId] = $this->createOrderLinesForScannedItems(
                $data['items'], (int) $data['client_id'], $userId, $shipmentDate
            );
            $this->receiveScannedCarpetsNotInStock($data['items'], $userId, $shipmentDate);

            // Inside the transaction, and holding row locks, so the balance we
            // read is the balance we write against. See instructions/phase-1/03.
            // Runs AFTER the auto-receipt above so it sees that stock, and
            // still has the last word before any OUT movement is written.
            $requestedPerVariant = $this->assertSufficientStock($data['items']);

            // currency/exchange_rate/vat_rate default to the pre-phase-3
            // behaviour exactly (USD, rate 1, no VAT) for every request
            // that does not send them — which is every request today, since
            // no client build sends these fields yet. See
            // instructions/phase-3/04-currency-vat-discount.md.
            $currency     = $data['currency']      ?? Shipment::BASE_CURRENCY;
            $exchangeRate = $data['exchange_rate']  ?? 1;
            $vatRate      = $data['vat_rate']       ?? 0;

            // ── 1. Shipment header ──────────────────────────────────────────
            $shipment = Shipment::create([
                'client_id'          => $data['client_id'],
                'user_id'            => $userId,
                'order_id'           => $data['order_id'] ?? null,
                'shipment_datetime'  => $shipmentDate,
                'notes'              => $data['notes'] ?? null,
                'currency'           => $currency,
                'exchange_rate'      => $exchangeRate,
                'vat_rate'           => $vatRate,
                // vat_amount is filled in after items are written — it is
                // round(subtotal x vat_rate, 2), and subtotal is not known
                // until every line's gross/discount has been computed below.
            ]);

            // Now that the shipment has an id, point the invented order back
            // at it, so cancelling the shipment can cancel that order without
            // having to guess which one it created.
            if ($autoOrderId !== null) {
                Order::whereKey($autoOrderId)
                    ->update(['created_from_shipment_id' => $shipment->id]);
            }

            // ── 2. Companion warehouse OUT document ─────────────────────────
            $warehouseDoc = WarehouseDocument::create([
                'type'          => WarehouseDocument::TYPE_OUT,
                'user_id'       => $userId,
                'document_date' => $shipmentDate->toDateString(),
                'notes'         => $data['notes'] ?? null,
            ]);
            $warehouseDocId = $warehouseDoc->id;

            // ── 3. Items ────────────────────────────────────────────────────
            $subtotal = '0.00';
            foreach ($data['items'] as $itemData) {
                $variantId = (int) $itemData['product_variant_id'];
                $qty       = (int) $itemData['quantity'];
                // Priced later, on the shipment page, for everything the app
                // sends today — see updatePrices().
                $price     = (float) ($itemData['price'] ?? 0);

                if (! array_key_exists($variantId, $requestedPerVariant)) {
                    // Cannot happen unless the check and the write disagree about
                    // the payload. If it ever does, fail loudly inside the
                    // transaction rather than write stock nobody validated.
                    throw new \LogicException(
                        "Variant {$variantId} was written but never stock-checked."
                    );
                }

                $shipmentItem = ShipmentItem::create([
                    'shipment_id'         => $shipment->id,
                    'order_item_id'       => $itemData['order_item_id'],
                    'product_variant_id'  => $variantId,
                    'quantity'            => $qty,
                    'price'               => $price,
                    'discount_type'       => $itemData['discount_type']  ?? 'none',
                    'discount_value'      => $itemData['discount_value'] ?? 0,
                ]);

                // discount_amount is the FROZEN cash value — computed once
                // here from gross (itself rounded once, at line 60-something
                // of ShipmentItem::grossAmount()) and discount_type/value,
                // then stored so a future rounding-rule change cannot alter
                // what an already-issued invoice printed. Defaults to 0.00
                // for every request that omits discount fields, which is
                // every request today. See
                // instructions/phase-3/04-currency-vat-discount.md.
                $shipmentItem->update(['discount_amount' => $shipmentItem->discountAmount()]);
                $subtotal = bcadd($subtotal, $shipmentItem->lineTotal(), 2);

                // Shipping must reduce `physical` (below, via the normal
                // stock_movement path) and `reserved` by the same amount, so
                // `available` does not move — the goods left, but so did the
                // claim on them. A missing/exhausted reservation is not an
                // error; shipping must never be blocked by a reservation
                // bookkeeping gap. See
                // instructions/phase-3/07-stock-reservations.md.
                $this->reservationService->consumeForOrderItem((int) $itemData['order_item_id'], $qty);

                $docItem = WarehouseDocumentItem::create([
                    'warehouse_document_id' => $warehouseDoc->id,
                    'product_variant_id'    => $variantId,
                    'quantity'              => $qty,
                    'source_type'           => 'shipment_item',
                    'source_id'             => $shipmentItem->id,
                ]);

                StockMovement::create([
                    'product_variant_id'         => $variantId,
                    'warehouse_document_item_id' => $docItem->id,
                    'user_id'                    => $userId,
                    'movement_type'              => WarehouseDocument::TYPE_OUT,
                    'quantity'                   => $qty,
                    'movement_date'              => $shipmentDate->toDateString(),
                ]);
                $this->stockService->applyDelta($variantId, StockMovement::TYPE_OUT, $qty);
            }

            // Carpets scanned off another client's production go with the
            // lorry, so their production record goes with them. Runs after the
            // lines are written because it needs the shipment id to be
            // reversible, and inside the transaction so a failed shipment
            // never leaves production half-moved.
            $this->reattributeScannedProduction(
                $data['items'], (int) $data['client_id'], (int) $shipment->id
            );

            // vat_amount = round(subtotal x vat_rate, 2) — applied to the
            // DISCOUNTED subtotal (config('money.vat_applies_to')), computed
            // once here and frozen. 0.00 whenever vat_rate is 0, which is
            // every shipment today. See
            // instructions/phase-3/04-currency-vat-discount.md.
            $vatAmount = $this->round2(bcmul($subtotal, (string) $vatRate, 8));
            $shipment->update(['vat_amount' => $vatAmount]);

            // ── 4. Update order status if fully shipped ─────────────────────
            // Every order a line ships against, not only the header's
            // order_id: scanned and stock-wizard shipments carry no order_id,
            // so a client order they finished used to stay "on production"
            // forever. Mirrors cancel(), which already reverts by line. The
            // auto-created order is among these lines, and is fully shipped
            // the moment this shipment is written.
            $orderIds = OrderItem::whereIn('id', array_column($data['items'], 'order_item_id'))
                ->pluck('order_id')
                ->push($shipment->order_id)
                ->filter()
                ->unique();

            foreach ($orderIds as $orderId) {
                $this->syncOrderShippedStatus((int) $orderId);
            }

            return $shipment->load([
                'client',
                'user',
                'items.variant.productColor.product.productQuality',
                'items.variant.productColor.color',
                'items.variant.productSize',
                'items.variant.productEdge',
            ]);
        });

        // Generate PDFs outside transaction to avoid memory buildup
        // Clear loaded relations before PDF generation to prevent memory issues
        try {
            $this->generateAndStoreInvoice($shipment->id);
        } catch (\Exception $e) {
            Log::error('Failed to generate shipment invoice', [
                'shipment_id' => $shipment->id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
        }

        try {
            $this->generateAndStoreHisobFaktura($shipment->id);
        } catch (\Exception $e) {
            Log::error('Failed to generate hisob faktura', [
                'shipment_id' => $shipment->id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
        }

        try {
            $this->generateAndStoreXlsx($shipment->id);
        } catch (\Exception $e) {
            Log::error('Failed to generate shipment XLSX', [
                'shipment_id' => $shipment->id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);
        }

        // Generate warehouse document PDF after the transaction so all items are committed
        if ($warehouseDocId !== null) {
            try {
                $warehouseDoc = WarehouseDocument::findOrFail($warehouseDocId);
                $pdfPath = $this->warehousePdfService->generatePdf($warehouseDoc);
                $warehouseDoc->update(['pdf_path' => $pdfPath]);
            } catch (\Exception $e) {
                Log::error('Failed to generate warehouse document PDF', [
                    'warehouse_doc_id' => $warehouseDocId,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        // Return fresh instance with minimal relations to avoid memory issues
        return Shipment::with([
            'client:id,contact_name,shop_name,phone',
            'user:id,name',
        ])->find($shipment->id);
    }

    /**
     * Generate the shipment invoice PDF, persist it to storage, and update
     * the shipment record with the stored path.
     */
    public function generateAndStoreInvoice(int $shipmentId): void
    {
        // Load fresh instance with only minimal required data to avoid memory issues
        $shipment = Shipment::select(['id', 'client_id', 'order_id', 'shipment_datetime', 'notes'])
            ->with([
                'client:id,contact_name,shop_name,phone,address,region',
                'items' => function ($q) {
                    $q->select(['id', 'shipment_id', 'product_variant_id', 'quantity', 'price']);
                },
                'items.variant:id,product_color_id,product_size_id,product_edge_id',
                'items.variant.productColor:id,product_id,color_id',
                'items.variant.productColor.product:id,name,product_quality_id,unit',
                'items.variant.productColor.product.productQuality:id,quality_name',
                'items.variant.productSize:id,length,width',
                'items.variant.productEdge:id,code,title',
            ])
            ->findOrFail($shipmentId);

        $pdf = Pdf::loadView('pdf.shipment_invoice', ['shipment' => $shipment])
            ->setPaper('a4', 'portrait')
            ->setOptions([
                'dpi' => 130, // Increased DPI for better quality
                'defaultFont' => 'sans-serif',
                'isRemoteEnabled' => false,
                'chroot' => storage_path('app'),
            ]);

        $relativePath = 'shipments/invoices/invoice_' . $shipmentId . '.pdf';

        Storage::disk('public')->put($relativePath, $pdf->output());

        Shipment::where('id', $shipmentId)->update(['pdf_path' => $relativePath]);

        // Clear memory
        unset($shipment, $pdf);
        gc_collect_cycles();
    }

    /**
     * Generate the hisob-faktura (price invoice) PDF with price_per_unit and
     * total price columns, persist it, and update invoice_path on the shipment.
     */
    public function generateAndStoreHisobFaktura(int $shipmentId): void
    {
        // Check if view exists
        if (!view()->exists('pdf.shipment_hisob_faktura')) {
            Log::error('Hisob faktura view not found', ['shipment_id' => $shipmentId]);
            throw new \Exception('Hisob faktura template not found');
        }

        // Load fresh instance with only minimal required data to avoid memory issues.
        // currency/exchange_rate/vat_rate/vat_amount and each item's discount
        // columns must be explicitly selected here or currencySymbol(),
        // grossAmount() and discountAmount() silently read null attributes —
        // see instructions/phase-3/04-currency-vat-discount.md.
        $shipment = Shipment::select(['id', 'client_id', 'order_id', 'shipment_datetime', 'notes', 'currency', 'exchange_rate', 'vat_rate', 'vat_amount'])
            ->with([
                'client:id,contact_name,shop_name,phone,address,region',
                'items' => function ($q) {
                    $q->select(['id', 'shipment_id', 'product_variant_id', 'quantity', 'price', 'discount_type', 'discount_value', 'discount_amount']);
                },
                'items.variant:id,product_color_id,product_size_id,product_edge_id',
                'items.variant.productColor:id,product_id,color_id',
                'items.variant.productColor.product:id,name,product_quality_id,unit',
                'items.variant.productColor.product.productQuality:id,quality_name',
                'items.variant.productColor.color:id,name',
                'items.variant.productSize:id,length,width',
                'items.variant.productEdge:id,code,title',
            ])
            ->findOrFail($shipmentId);

        $pdf = Pdf::loadView('pdf.shipment_hisob_faktura', ['shipment' => $shipment])
            ->setPaper('a4', 'portrait')
            ->setOptions([
                'dpi' => 130, // Increased DPI for better quality
                'defaultFont' => 'sans-serif',
                'isRemoteEnabled' => false,
                'chroot' => storage_path('app'),
            ]);

        $relativePath = 'shipments/hisob_faktura/faktura_' . $shipmentId . '.pdf';

        Storage::disk('public')->put($relativePath, $pdf->output());

        Shipment::where('id', $shipmentId)->update(['invoice_path' => $relativePath]);

        Log::info('Hisob faktura generated successfully', [
            'shipment_id' => $shipmentId,
            'path' => $relativePath,
        ]);

        // Clear memory
        unset($shipment, $pdf);
        gc_collect_cycles();
    }

    /**
     * Generate an XLSX shipment list with per-item detail rows, store it, and
     * update xlsx_path on the shipment record.
     *
     * Columns: Yuk chiqarish, Sana, Toliq nomi, Barcode, Yuklandi(soni),
     *          Yuklandi(m2), Sifat, Model, Rang, O'lcham, Kengligi, Uzunligi
     */
    public function generateAndStoreXlsx(int $shipmentId): void
    {
        $shipment = Shipment::select(['id', 'client_id', 'shipment_datetime'])
            ->with([
                'client:id,shop_name',
                'items' => fn ($q) => $q->select(['id', 'shipment_id', 'product_variant_id', 'quantity']),
                'items.variant:id,product_color_id,product_size_id,product_edge_id,barcode_value',
                'items.variant.productColor:id,product_id,color_id',
                'items.variant.productColor.product:id,name,product_quality_id,unit',
                'items.variant.productColor.product.productQuality:id,quality_name',
                'items.variant.productColor.color:id,name',
                'items.variant.productSize:id,length,width',
                'items.variant.productEdge:id,code',
            ])
            ->findOrFail($shipmentId);

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Yuk ro\'yxati');

        // ── Header row ─────────────────────────────────────────────────────
        $headers = [
            'A' => 'Yuk chiqarish',
            'B' => 'Sana',
            'C' => 'Toliq nomi',
            'D' => 'Barcode',
            'E' => 'Yuklandi (soni)',
            'F' => 'Yuklandi (m2)',
            'G' => 'Sifat',
            'H' => 'Model',
            'I' => 'Rang',
            'J' => "O'lcham",
            'K' => 'Kengligi',
            'L' => 'Uzunligi',
        ];

        foreach ($headers as $col => $label) {
            $sheet->setCellValue("{$col}1", $label);
        }

        $headerStyle = [
            'font'      => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
            'fill'      => ['fillType' => Fill::FILL_SOLID, 'startColor' => ['rgb' => '2E5BA8']],
            'alignment' => ['horizontal' => Alignment::HORIZONTAL_CENTER, 'vertical' => Alignment::VERTICAL_CENTER],
            'borders'   => ['allBorders' => ['borderStyle' => Border::BORDER_THIN, 'color' => ['rgb' => 'CCCCCC']]],
        ];
        $sheet->getStyle('A1:L1')->applyFromArray($headerStyle);
        $sheet->getRowDimension(1)->setRowHeight(22);

        // ── Data rows ──────────────────────────────────────────────────────
        $shipmentDate = $shipment->shipment_datetime?->format('d.m.Y') ?? '';

        $row = 2;
        foreach ($shipment->items as $item) {
            $variant = $item->variant;
            $product = $variant?->productColor?->product;
            $color   = $variant?->productColor?->color;
            $size    = $variant?->productSize;
            $edge    = $variant?->productEdge;
            $quality = $product?->productQuality;

            $width   = $size?->width   ?? 0;
            $length  = $size?->length  ?? 0;
            $qty     = $item->quantity;
            $sqm     = ($width * $length * $qty) / 10000.0;

            $sizeLabel    = ($width && $length) ? "{$width}x{$length}" : '';
            $qualityName  = $quality?->quality_name  ?? '';
            $productName  = $product?->name          ?? '';
            $colorName    = $color?->name            ?? '';
            $edgeCode     = $edge?->code             ?? '';
            $fullName     = trim("{$qualityName} {$productName} {$colorName} {$sizeLabel} {$edgeCode}");

            $sheet->setCellValue("A{$row}", $shipmentId);
            $sheet->setCellValue("B{$row}", $shipmentDate);
            $sheet->setCellValue("C{$row}", $fullName);
            // Explicit text: Excel shows a 13-digit number as 2.98420E+12.
            $sheet->setCellValueExplicit("D{$row}", $variant?->barcode_value ?? '', DataType::TYPE_STRING);
            $sheet->setCellValue("E{$row}", $qty);
            $sheet->setCellValue("F{$row}", round($sqm, 4));
            $sheet->setCellValue("G{$row}", $qualityName);
            $sheet->setCellValue("H{$row}", $productName);
            $sheet->setCellValue("I{$row}", $colorName);
            $sheet->setCellValue("J{$row}", $sizeLabel);
            $sheet->setCellValue("K{$row}", $width);
            $sheet->setCellValue("L{$row}", $length);

            $sheet->getStyle("A{$row}:L{$row}")->applyFromArray([
                'borders'   => ['allBorders' => ['borderStyle' => Border::BORDER_THIN, 'color' => ['rgb' => 'DDDDDD']]],
                'alignment' => ['vertical' => Alignment::VERTICAL_CENTER],
            ]);

            $row++;
        }

        // ── Column widths ──────────────────────────────────────────────────
        $widths = ['A' => 14, 'B' => 12, 'C' => 40, 'D' => 18, 'E' => 14, 'F' => 14,
                   'G' => 14, 'H' => 20, 'I' => 14, 'J' => 10, 'K' => 10, 'L' => 10];
        foreach ($widths as $col => $w) {
            $sheet->getColumnDimension($col)->setWidth($w);
        }

        // ── Write to storage ───────────────────────────────────────────────
        $relativePath = "shipments/xlsx/shipment_{$shipmentId}.xlsx";
        $absolutePath = Storage::disk('public')->path($relativePath);

        Storage::disk('public')->makeDirectory('shipments/xlsx');

        $writer = new Xlsx($spreadsheet);
        $writer->save($absolutePath);

        Shipment::where('id', $shipmentId)->update(['xlsx_path' => $relativePath]);

        unset($spreadsheet, $writer, $shipment);
        gc_collect_cycles();
    }

    /**
     * Return the most recent price charged for a given variant and client.
     * Returns null when no prior shipment exists.
     *
     * $currency, when given, restricts the lookup to shipments in that
     * currency — prefilling last time's price from a shipment in a
     * DIFFERENT currency is a catastrophic default (offering last time's
     * 1,200,000 UZS as this time's USD price). $currency defaults to null
     * (no filter) rather than defaulting to base currency, because every
     * shipment in the database is 'USD' today and filtering would be a
     * no-op — this keeps the method's behaviour for the one caller that
     * exists today (no client sends a currency yet) exactly unchanged,
     * while giving a future currency-aware caller the real guarantee.
     * See instructions/phase-3/04-currency-vat-discount.md #5.
     *
     * Deliberately reads `price` (pre-discount), not the net/discounted
     * figure — prefilling a past discount is the mechanism that makes a
     * one-off concession a permanent price cut (getLastPrice() itself
     * would keep propagating it forever).
     */
    public function getLastPrice(int $variantId, int $clientId, ?string $currency = null): ?float
    {
        // A cancelled shipment sets no precedent for what this client pays.
        $price = ShipmentItem::whereHas(
            'shipment',
            fn ($q) => $q->where('client_id', $clientId)
                ->whereNull('canceled_at')
                ->when($currency !== null, fn ($q2) => $q2->where('currency', $currency))
        )
            ->where('product_variant_id', $variantId)
            ->orderByDesc('created_at')
            ->value('price');

        return $price !== null ? (float) $price : null;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * @param  array<int, array{product_variant_id: int|string, quantity: int|string}>  $items
     * @return array<int, int>  variantId => total requested, for reuse by the caller
     *
     * INTERIM (phase-1 step 03): product_variants is a proxy lock. The real
     * balance is a SUM over stock_movements. Every writer must take this lock
     * for it to mean anything — WarehouseDocumentService currently does not.
     * Phase-2 replaces this with a lockable product_variant_stock balance row.
     */
    /**
     * Cancel a shipment and put everything it moved back.
     *
     * The shipment row stays, marked — a client was shown this document, and
     * "cancelled by X on Y because Z" is worth more than a hole in the
     * numbering. What must not stay is its effect: the carpets return to the
     * warehouse, the order lines become unshipped, the client stops owing for
     * them (every money query filters on canceled_at), and an order this
     * shipment invented for a scanned off-order carpet is cancelled with it.
     *
     * Stock returns as a compensating IN document rather than by deleting the
     * original OUT movements: stock_movements is the ledger the nightly
     * stock:reconcile checks product_variant_stock against, and a ledger that
     * quietly loses rows cannot be audited. The history reads "went out on
     * the 3rd, came back on the 5th", which is what actually happened.
     */
    public function cancel(Shipment $shipment, int $userId, ?string $reason = null): Shipment
    {
        if ($shipment->isCanceled()) {
            throw ValidationException::withMessages([
                'shipment' => 'Bu yuk xati allaqachon bekor qilingan.',
            ]);
        }

        return DB::transaction(function () use ($shipment, $userId, $reason): Shipment {
            // Re-read under a lock and re-check: two admins hitting cancel at
            // the same moment would otherwise both pass the guard above and
            // each write a compensating IN, returning the goods twice.
            $shipment = Shipment::whereKey($shipment->id)->lockForUpdate()->first();

            if ($shipment === null || $shipment->isCanceled()) {
                throw ValidationException::withMessages([
                    'shipment' => 'Bu yuk xati allaqachon bekor qilingan.',
                ]);
            }

            $shipment->load('items');

            // ── 1. Carpets back into the warehouse ──────────────────────────
            $returnDoc = WarehouseDocument::create([
                'type'          => WarehouseDocument::TYPE_IN,
                'client_id'     => $shipment->client_id,
                'user_id'       => $userId,
                'document_date' => now()->toDateString(),
                'notes'         => "#{$shipment->id} yuk xati bekor qilinishi bo'yicha qaytarilgan mahsulotlar.",
            ]);

            foreach ($shipment->items as $item) {
                $docItem = WarehouseDocumentItem::create([
                    'warehouse_document_id' => $returnDoc->id,
                    'product_variant_id'    => $item->product_variant_id,
                    'quantity'              => $item->quantity,
                    'source_type'           => 'shipment_item',
                    'source_id'             => $item->id,
                ]);

                StockMovement::create([
                    'product_variant_id'         => $item->product_variant_id,
                    'warehouse_document_item_id' => $docItem->id,
                    'user_id'                    => $userId,
                    'movement_type'              => WarehouseDocument::TYPE_IN,
                    'quantity'                   => $item->quantity,
                    'movement_date'              => now()->toDateString(),
                ]);
                $this->stockService->applyDelta(
                    (int) $item->product_variant_id, StockMovement::TYPE_IN, (int) $item->quantity
                );

                // The order line is owed again, so its claim on the stock is
                // owed again too.
                $this->reservationService->restoreForOrderItem(
                    (int) $item->order_item_id, (int) $item->quantity
                );
            }

            // ── 2. Mark it, before anything recomputes shipped quantities ───
            $shipment->update([
                'canceled_at'   => now(),
                'canceled_by'   => $userId,
                'cancel_reason' => $reason,
            ]);

            // ── 3. Orders that this shipment had closed ─────────────────────
            $orderIds = OrderItem::whereIn('id', $shipment->items->pluck('order_item_id'))
                ->pluck('order_id')
                ->push($shipment->order_id)
                ->filter()
                ->unique();

            foreach ($orderIds as $orderId) {
                $this->revertOrderShippedStatus((int) $orderId);
            }

            // ── 4. An order this shipment invented goes with it ─────────────
            Order::where('created_from_shipment_id', $shipment->id)
                ->update(['status' => Order::STATUS_CANCELED]);

            // ── 5. Production this shipment took from another client ────────
            // The carpets came back in step 1, so the client they were made
            // for is owed them again and their "Tayyor" count must show it.
            // Rows that were split on the way out stay split on the way back:
            // the two rows add up to what the one row held, which is what any
            // report reads, and merging them would rewrite a batch to hide a
            // move that really happened.
            $returned = ProductionBatchItem::where('reattributed_by_shipment_id', $shipment->id)
                ->whereNotNull('reattributed_from_order_item_id')
                ->get();
            $returnedToOrders = $this->ordersReattributedFrom((int) $shipment->id);

            foreach ($returned as $batchItem) {
                $batchItem->update([
                    'source_order_item_id'            => $batchItem->reattributed_from_order_item_id,
                    'reattributed_from_order_item_id' => null,
                    'reattributed_by_shipment_id'     => null,
                ]);
            }

            foreach ($returnedToOrders as $orderId) {
                $this->refreshProductionStatus($orderId, afterReturn: true);
            }

            Log::info('shipment.canceled', [
                'shipment_id'           => $shipment->id,
                'user_id'               => $userId,
                'client_id'             => $shipment->client_id,
                'items'                 => $shipment->items->count(),
                'return_document_id'    => $returnDoc->id,
                'production_returned'   => $returned->count(),
            ]);

            return $shipment->fresh(['client', 'user', 'canceledBy', 'items']);
        });
    }

    /**
     * Writes prices onto an existing shipment's lines and rebuilds its
     * documents from them.
     *
     * The shipment itself does not move: no stock, no order lines, no
     * quantities. What changes is what the client owes — the debt is a SUM
     * over shipment_items, so it follows these prices the moment they are
     * saved — and the three generated documents, which are regenerated here
     * because a hisob-faktura printed from 0.00 prices is worse than none.
     *
     * A cancelled shipment is refused: its goods came back and nobody owes
     * anything for them, so pricing it would resurrect a debt that was
     * deliberately dropped.
     *
     * @param array<int, array<string, mixed>> $items {id, price, discount_*}
     */
    public function updatePrices(Shipment $shipment, array $items, int $userId): Shipment
    {
        if ($shipment->isCanceled()) {
            throw ValidationException::withMessages([
                'shipment' => 'Bekor qilingan yuk xatiga narx kiritib bo\'lmaydi.',
            ]);
        }

        DB::transaction(function () use ($shipment, $items): void {
            // Re-read under a lock: two people pricing the same shipment from
            // two phones would otherwise each compute vat_amount from their
            // own half of the lines.
            $shipment = Shipment::whereKey($shipment->id)->lockForUpdate()->first();

            $priced = collect($items)->keyBy('id');

            foreach ($shipment->items()->lockForUpdate()->get() as $item) {
                $update = $priced->get($item->id);
                if ($update === null) {
                    continue;   // line left untouched by this save
                }

                $item->update([
                    'price'          => $update['price'],
                    'discount_type'  => $update['discount_type']  ?? $item->discount_type,
                    'discount_value' => $update['discount_value'] ?? $item->discount_value,
                ]);

                // Frozen cash value of the discount, recomputed from the new
                // price exactly as create() does — the two must not drift.
                $item->update(['discount_amount' => $item->discountAmount()]);
            }

            // vat_amount is derived from the discounted subtotal and stored,
            // so it has to be rebuilt from the lines as they now stand.
            $subtotal = '0.00';
            foreach ($shipment->items()->get() as $item) {
                $subtotal = bcadd($subtotal, $item->lineTotal(), 2);
            }

            $shipment->update([
                'vat_amount' => $this->round2(
                    bcmul($subtotal, (string) ($shipment->vat_rate ?? 0), 8)
                ),
            ]);
        });

        // Outside the transaction, like create(): PDF rendering is slow and
        // memory-hungry, and a failed render must not roll back prices that
        // are already correct. A document that fails here is rebuilt by the
        // next save.
        try {
            $this->generateAndStoreInvoice($shipment->id);
        } catch (\Exception $e) {
            Log::error('Failed to regenerate shipment invoice after pricing', [
                'shipment_id' => $shipment->id,
                'error'       => $e->getMessage(),
            ]);
        }

        try {
            $this->generateAndStoreHisobFaktura($shipment->id);
        } catch (\Exception $e) {
            Log::error('Failed to regenerate hisob faktura after pricing', [
                'shipment_id' => $shipment->id,
                'error'       => $e->getMessage(),
            ]);
        }

        try {
            $this->generateAndStoreXlsx($shipment->id);
        } catch (\Exception $e) {
            Log::error('Failed to regenerate shipment XLSX after pricing', [
                'shipment_id' => $shipment->id,
                'error'       => $e->getMessage(),
            ]);
        }

        Log::info('shipment.prices_updated', [
            'shipment_id' => $shipment->id,
            'user_id'     => $userId,
            'lines'       => count($items),
        ]);

        return $shipment->fresh([
            'client',
            'user',
            'items.variant.productColor.product',
            'items.variant.productColor.color',
            'items.variant.productSize',
            'items.variant.productEdge',
            'items.orderItem.order',
        ]);
    }

    /**
     * The counterpart of syncOrderShippedStatus(): an order marked shipped
     * that no longer is — because the shipment that closed it was cancelled —
     * goes back to 'done'. Only 'shipped' is touched; an order someone
     * cancelled by hand stays cancelled.
     */
    private function revertOrderShippedStatus(int $orderId): void
    {
        $order = Order::with('items.shipmentItems')->find($orderId);

        if (! $order || $order->status !== Order::STATUS_SHIPPED) {
            return;
        }

        // shipmentItems already excludes cancelled shipments, so this is the
        // post-cancellation truth.
        $allShipped = $order->items->isNotEmpty() && $order->items->every(
            fn ($item) => $item->shipmentItems->sum('quantity') >= $item->quantity
        );

        if (! $allShipped) {
            $order->update(['status' => Order::STATUS_DONE]);
        }
    }

    /**
     * Gives every scanned line without an `order_item_id` one to hang off.
     *
     * `shipment_items.order_item_id` is NOT NULL, so "ship a carpet this client
     * never ordered" has to become "this client ordered it, and here it is" —
     * one order per shipment holding exactly the added-anyway lines, so the
     * invented demand is visibly separate from what the client actually asked
     * for. It is created here, at submit time, so a worker who scans a carpet
     * and then abandons the form leaves nothing behind.
     *
     * The carpet may well have been produced against a DIFFERENT client's
     * order. That other order line is deliberately left alone: it is still
     * unshipped, still owed, and production still has to cover it. The app
     * names that client in the confirmation sheet before any of this runs.
     *
     * @return array{0: array<int, array<string, mixed>>, 1: int|null} items with
     *         order_item_id filled in, and the auto-created order id (or null)
     */
    private function createOrderLinesForScannedItems(
        array $items,
        int $clientId,
        int $userId,
        Carbon $shipmentDate,
    ): array {
        $needsLine = [];
        foreach ($items as $index => $item) {
            if (($item['order_item_id'] ?? null) === null) {
                $needsLine[$index] = (int) $item['product_variant_id'];
            }
        }

        if ($needsLine === []) {
            return [$items, null];
        }

        $order = Order::create([
            'user_id'    => $userId,
            'client_id'  => $clientId,
            'status'     => Order::STATUS_DONE,
            'order_date' => $shipmentDate->toDateString(),
            'notes'      => 'Yuk xati bilan avtomatik yaratildi: skanerlangan, '
                . 'lekin mijozning ochiq buyurtmasida bo\'lmagan mahsulotlar.',
        ]);

        // One order line per shipment line, quantity matched, so the order is
        // exactly satisfied by this shipment and syncOrderShippedStatus() can
        // close it. Two scans of the same variant arrive as one line with
        // quantity 2, so this does not fragment.
        foreach ($needsLine as $index => $variantId) {
            $orderItem = $order->items()->create([
                'product_variant_id' => $variantId,
                'quantity'           => (int) $items[$index]['quantity'],
            ]);

            $items[$index]['order_item_id'] = $orderItem->id;
        }

        Log::info('shipment.scan.order_auto_created', [
            'order_id'  => $order->id,
            'client_id' => $clientId,
            'user_id'   => $userId,
            'lines'     => count($needsLine),
        ]);

        return [$items, $order->id];
    }

    /**
     * Moves the production record of scanned carpets onto the order line they
     * are actually shipping against.
     *
     * A worker scans the label on the carpet in front of them. That carpet was
     * often produced against a DIFFERENT client's order — the factory makes
     * identical carpets and the first one to hand goes on the lorry. Until
     * this ran, the production record stayed with the client it was made for,
     * so their order kept showing the carpet as "Tayyor" (ready) while it was
     * already in someone else's shop. The next person to look would ship a
     * carpet that no longer exists.
     *
     * What moves is only the claim, never the total: the carpets come off the
     * original batch item and land on a batch item pointing at the receiving
     * client's line, in the same batch. SUM(produced_quantity) over the
     * factory does not change — the factory made what it made. The original
     * client's order is short again (planned drops with produced), so it
     * reappears in the "needs production" list and the factory owes them a
     * replacement, which is exactly the physical truth.
     *
     * Deliberately does nothing for:
     *   - warehouse carpets (`source_order_item_id` null) — nobody was
     *     promised them, and the stock OUT movement already accounts for them;
     *   - carpets already attributed to this same client.
     *
     * @param array<int, array<string, mixed>> $items post-createOrderLines, so
     *        every line has an order_item_id
     */
    private function reattributeScannedProduction(
        array $items,
        int $clientId,
        int $shipmentId,
    ): void {
        foreach ($items as $item) {
            if (! filter_var($item['scanned'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
                continue;
            }

            $batchItemIds = $item['scanned_batch_item_ids'] ?? [];
            if (! is_array($batchItemIds) || $batchItemIds === []) {
                continue;
            }

            $targetOrderItemId = (int) $item['order_item_id'];
            $remaining         = (int) $item['quantity'];

            // One id per carpet scanned, so two carpets off the same batch
            // item arrive as the same id twice. Capped by the line quantity:
            // a worker may have scanned three and then typed 2.
            foreach (array_count_values(array_map('intval', $batchItemIds)) as $batchItemId => $count) {
                if ($remaining <= 0) {
                    break;
                }

                $remaining -= $this->moveProducedCarpets(
                    (int) $batchItemId,
                    min($count, $remaining),
                    $targetOrderItemId,
                    $clientId,
                    $shipmentId,
                );
            }
        }

        // The orders the carpets were taken from are short again. One that was
        // 'done' is invisible to the "needs production" list (it filters on
        // pending/planned/on_production), so the replacement the factory now
        // owes would never be made.
        foreach ($this->ordersReattributedFrom($shipmentId) as $orderId) {
            $this->refreshProductionStatus($orderId, afterReturn: false);
        }
    }

    /**
     * Ids of the orders that [$shipmentId] took produced carpets from.
     *
     * @return array<int, int>
     */
    private function ordersReattributedFrom(int $shipmentId): array
    {
        return DB::table('production_batch_items AS pbi')
            ->join('order_items AS oi', 'oi.id', '=', 'pbi.reattributed_from_order_item_id')
            ->where('pbi.reattributed_by_shipment_id', $shipmentId)
            ->distinct()
            ->pluck('oi.order_id')
            ->map(fn ($id) => (int) $id)
            ->all();
    }

    /**
     * Re-derives the production status of an order whose produced carpets
     * were moved by a shipment: away from it on create ([$afterReturn]
     * false), or back to it on cancel (true).
     *
     * Moving away only ever demotes: an order no longer covered by planned
     * production goes back to 'pending' (as ProductionBatchService does when
     * a batch is cancelled), and a 'done' order that still is covered goes
     * back to 'on_production'. Moving back only ever promotes, and only as
     * far as the numbers show: covered again → 'on_production', every carpet
     * in the warehouse again → 'done'. Shipped and cancelled orders are never
     * touched.
     */
    private function refreshProductionStatus(int $orderId, bool $afterReturn): void
    {
        $order = Order::with('items')->find($orderId);

        if (! $order || $order->items->isEmpty() || ! in_array($order->status, [
            Order::STATUS_PENDING,
            Order::STATUS_PLANNED,
            Order::STATUS_ON_PRODUCTION,
            Order::STATUS_DONE,
        ], true)) {
            return;
        }

        $itemIds = $order->items->pluck('id');

        $planned = DB::table('production_batch_items AS pbi')
            ->join('production_batches AS pb', 'pb.id', '=', 'pbi.production_batch_id')
            ->whereIn('pbi.source_order_item_id', $itemIds)
            ->where('pb.status', '!=', \App\Models\ProductionBatch::STATUS_CANCELLED)
            ->groupBy('pbi.source_order_item_id')
            ->selectRaw('pbi.source_order_item_id AS id, SUM(pbi.planned_quantity) AS qty')
            ->pluck('qty', 'id');

        // All batches, cancelled ones included, as WarehouseDocumentService
        // counts it: a received carpet exists whatever became of its batch.
        $received = DB::table('production_batch_items')
            ->whereIn('source_order_item_id', $itemIds)
            ->groupBy('source_order_item_id')
            ->selectRaw('source_order_item_id AS id, SUM(warehouse_received_quantity) AS qty')
            ->pluck('qty', 'id');

        $allPlanned  = $order->items->every(fn ($i) => (int) ($planned[$i->id] ?? 0) >= $i->quantity);
        $allReceived = $order->items->every(fn ($i) => (int) ($received[$i->id] ?? 0) >= $i->quantity);

        $status = $order->status;
        if (! $afterReturn) {
            if (! $allPlanned) {
                $status = Order::STATUS_PENDING;
            } elseif ($status === Order::STATUS_DONE && ! $allReceived) {
                $status = Order::STATUS_ON_PRODUCTION;
            }
        } elseif ($allPlanned) {
            if ($allReceived) {
                $status = Order::STATUS_DONE;
            } elseif ($status === Order::STATUS_PENDING) {
                $status = Order::STATUS_ON_PRODUCTION;
            }
        }

        if ($status !== $order->status) {
            Log::info('shipment.scan.order_status_refreshed', [
                'order_id' => $order->id,
                'from'     => $order->status,
                'to'       => $status,
                'reason'   => $afterReturn ? 'production_returned' : 'production_taken',
            ]);
            $order->update(['status' => $status]);
        }
    }

    /**
     * Moves up to [$quantity] produced carpets from [$batchItemId] to
     * [$targetOrderItemId], and returns how many actually moved.
     *
     * The batch item may cover more carpets than are shipping — one batch item
     * routinely stands for a dozen — so it is split rather than repointed: the
     * original keeps what stays behind, and a new row in the same batch
     * carries what left. planned and warehouse_received travel with produced
     * so that neither the "still to produce" nor the "still to book in" list
     * counts the same carpet twice; defects stay with the original, where they
     * happened.
     */
    private function moveProducedCarpets(
        int $batchItemId,
        int $quantity,
        int $targetOrderItemId,
        int $clientId,
        int $shipmentId,
    ): int {
        if ($quantity <= 0) {
            return 0;
        }

        $batchItem = ProductionBatchItem::whereKey($batchItemId)->lockForUpdate()->first();

        if (! $batchItem || $batchItem->source_order_item_id === null) {
            return 0;   // a warehouse carpet: nobody's order to take it from
        }

        if ((int) $batchItem->source_order_item_id === $targetOrderItemId) {
            return 0;   // already where it is shipping from
        }

        $sourceOrderItem = OrderItem::with('order')->find($batchItem->source_order_item_id);

        if (! $sourceOrderItem || (int) ($sourceOrderItem->order?->client_id) === $clientId) {
            return 0;   // this client's own carpet, on another of their lines
        }

        // Only produced carpets can move. A batch item with produced 0 is a
        // plan, not a carpet; the label in the worker's hand says otherwise,
        // but rewriting production totals off a scan is not this method's job.
        $moved = min($quantity, (int) $batchItem->produced_quantity);
        if ($moved <= 0) {
            return 0;
        }

        $plannedMove  = min($moved, (int) $batchItem->planned_quantity);
        $receivedMove = min($moved, (int) $batchItem->warehouse_received_quantity);

        // Whole row: nothing would be left behind, so moving the row itself
        // keeps the batch one row shorter and the history readable.
        $wholeRow = $moved === (int) $batchItem->produced_quantity
            && $plannedMove === (int) $batchItem->planned_quantity
            && $receivedMove === (int) $batchItem->warehouse_received_quantity
            && (int) $batchItem->defect_quantity === 0;

        if ($wholeRow) {
            $batchItem->update([
                'source_type'                     => ProductionBatchItem::SOURCE_ORDER_ITEM,
                'source_order_item_id'            => $targetOrderItemId,
                // Chained moves keep the first origin: cancelling this
                // shipment must return the carpet to the client that was
                // promised it, not to an intermediate hop.
                'reattributed_from_order_item_id' => $batchItem->reattributed_from_order_item_id
                    ?? $batchItem->source_order_item_id,
                'reattributed_by_shipment_id'     => $shipmentId,
            ]);
        } else {
            $batchItem->update([
                'planned_quantity'            => (int) $batchItem->planned_quantity - $plannedMove,
                'produced_quantity'           => (int) $batchItem->produced_quantity - $moved,
                'warehouse_received_quantity' => (int) $batchItem->warehouse_received_quantity - $receivedMove,
            ]);

            ProductionBatchItem::create([
                'production_batch_id'             => $batchItem->production_batch_id,
                'source_type'                     => ProductionBatchItem::SOURCE_ORDER_ITEM,
                'source_order_item_id'            => $targetOrderItemId,
                'reattributed_from_order_item_id' => $batchItem->source_order_item_id,
                'reattributed_by_shipment_id'     => $shipmentId,
                'product_variant_id'              => $batchItem->product_variant_id,
                'planned_quantity'                => $plannedMove,
                'produced_quantity'               => $moved,
                'defect_quantity'                 => 0,
                'warehouse_received_quantity'     => $receivedMove,
                'notes'                           => "#{$shipmentId} yuk xati bilan skanerlab jo'natildi "
                    . "(avval #{$batchItem->source_order_item_id} buyurtma qatoriga tegishli edi).",
            ]);
        }

        Log::info('shipment.scan.production_reattributed', [
            'shipment_id'            => $shipmentId,
            'production_batch_item'  => $batchItem->id,
            'from_order_item_id'     => $sourceOrderItem->id,
            'from_client_id'         => $sourceOrderItem->order?->client_id,
            'to_order_item_id'       => $targetOrderItemId,
            'to_client_id'           => $clientId,
            'quantity'               => $moved,
            'whole_row'              => $wholeRow,
        ]);

        return $moved;
    }

    /**
     * Books in scanned carpets the warehouse never received.
     *
     * A label in a worker's hand is evidence the carpet exists; a missing
     * stock_movement only means nobody recorded it arriving. Rather than
     * refuse the shipment (assertSufficientStock would) or let the ledger go
     * negative, the shortfall is received here as a normal warehouse IN
     * document, so the carpet's life is still in → out and every stock report
     * stays add-up-able.
     *
     * Only shortfalls on variants with at least one scanned line are covered:
     * a wizard line short on stock is still a real error and still throws.
     */
    private function receiveScannedCarpetsNotInStock(
        array $items,
        int $userId,
        Carbon $shipmentDate,
    ): void {
        $requestedPerVariant = [];
        $scannedVariants     = [];

        foreach ($items as $item) {
            $variantId = (int) $item['product_variant_id'];
            $requestedPerVariant[$variantId] = ($requestedPerVariant[$variantId] ?? 0) + (int) $item['quantity'];

            if (filter_var($item['scanned'] ?? false, FILTER_VALIDATE_BOOLEAN)) {
                $scannedVariants[$variantId] = true;
            }
        }

        if ($scannedVariants === []) {
            return;
        }

        // Same lock, same order, as assertSufficientStock() — so two shipments
        // scanning the same carpet cannot both read "no stock" and each book
        // one in.
        $lockIds = array_keys($scannedVariants);
        sort($lockIds);
        ProductVariant::whereIn('id', $lockIds)->orderBy('id')->lockForUpdate()->get();

        $shortfalls = [];
        foreach ($requestedPerVariant as $variantId => $requested) {
            if (! isset($scannedVariants[$variantId])) {
                continue;
            }

            $shortfall = $requested - $this->getStock($variantId);
            if ($shortfall > 0) {
                $shortfalls[$variantId] = $shortfall;
            }
        }

        if ($shortfalls === []) {
            return;
        }

        $document = WarehouseDocument::create([
            'type'          => WarehouseDocument::TYPE_IN,
            'user_id'       => $userId,
            'document_date' => $shipmentDate->toDateString(),
            'notes'         => 'Yuk xati uchun avtomatik qabul: skanerlangan, '
                . 'lekin omborga kirim qilinmagan mahsulotlar.',
        ]);

        foreach ($shortfalls as $variantId => $quantity) {
            $docItem = WarehouseDocumentItem::create([
                'warehouse_document_id' => $document->id,
                'product_variant_id'    => $variantId,
                'quantity'              => $quantity,
                'notes'                 => 'Skanerlangan yorliq asosida.',
            ]);

            StockMovement::create([
                'product_variant_id'         => $variantId,
                'warehouse_document_item_id' => $docItem->id,
                'user_id'                    => $userId,
                'movement_type'              => WarehouseDocument::TYPE_IN,
                'quantity'                   => $quantity,
                'movement_date'              => $shipmentDate->toDateString(),
            ]);
            $this->stockService->applyDelta($variantId, StockMovement::TYPE_IN, $quantity);
        }

        Log::info('shipment.scan.stock_auto_received', [
            'warehouse_document_id' => $document->id,
            'user_id'               => $userId,
            'variants'              => $shortfalls,
        ]);
    }

    private function assertSufficientStock(array $items): array
    {
        // Sum every line per variant BEFORE checking. Two lines of the same
        // variant must be checked against their combined total.
        $requestedPerVariant = [];
        $lineIndexes         = [];

        foreach ($items as $index => $itemData) {
            $variantId = (int) $itemData['product_variant_id'];
            $requestedPerVariant[$variantId] = ($requestedPerVariant[$variantId] ?? 0) + (int) $itemData['quantity'];
            $lineIndexes[$variantId][]       = $index;
        }

        // Lock all involved variant rows in a stable order to avoid deadlocks
        // between two shipments touching an overlapping set of variants.
        $variantIds = array_keys($requestedPerVariant);
        sort($variantIds);

        ProductVariant::whereIn('id', $variantIds)
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        $errors = [];

        foreach ($requestedPerVariant as $variantId => $requested) {
            $currentStock = $this->getStock($variantId);

            if ($currentStock < $requested) {
                // Attach the error to the first line for this variant so the UI
                // has somewhere to put it.
                $firstIndex = $lineIndexes[$variantId][0];
                $lineCount  = count($lineIndexes[$variantId]);

                $errors["items.{$firstIndex}.quantity"] = [
                    $lineCount > 1
                        ? "Insufficient stock for variant ID {$variantId}. Available: {$currentStock}, Requested: {$requested} across {$lineCount} lines."
                        : "Insufficient stock for variant ID {$variantId}. Available: {$currentStock}, Requested: {$requested}.",
                ];
            }
        }

        if (! empty($errors)) {
            throw ValidationException::withMessages($errors);
        }

        return $requestedPerVariant;
    }

    /** bcmath truncates; this rounds half-up, matching ShipmentItem::round2(). */
    private function round2(string $value): string
    {
        $add = str_starts_with($value, '-') ? '-0.005' : '0.005';

        return bcadd($value, $add, 2);
    }

    private function getStock(int $variantId): int
    {
        $base = StockMovement::where('product_variant_id', $variantId);

        $in  = (clone $base)
            ->where('movement_type', StockMovement::TYPE_IN)
            ->sum('quantity');

        $out = (clone $base)
            ->where('movement_type', StockMovement::TYPE_OUT)
            ->sum('quantity');

        return (int) ($in - $out);
    }

    private function syncOrderShippedStatus(int $orderId): void
    {
        $order = Order::with('items.shipmentItems')->find($orderId);

        if (! $order || ! in_array($order->status, [
            Order::STATUS_ON_PRODUCTION,
            Order::STATUS_DONE,
            Order::STATUS_PLANNED,
            Order::STATUS_PENDING,
        ])) {
            return;
        }

        if ($order->items->isEmpty()) {
            return;
        }

        $allShipped = $order->items->every(
            fn ($item) => $item->shipmentItems->sum('quantity') >= $item->quantity
        );

        if ($allShipped) {
            $order->update(['status' => Order::STATUS_SHIPPED]);
        }
    }
}
