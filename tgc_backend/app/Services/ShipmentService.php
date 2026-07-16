<?php

namespace App\Services;

use App\Models\Order;
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
     *   1. Validate sufficient stock for every variant.
     *   2. Create the Shipment header.
     *   3. Create a WarehouseDocument of type 'out' to represent the outgoing stock.
     *   4. For each item: create ShipmentItem → WarehouseDocumentItem → StockMovement.
     *   5. If the linked order's items are fully shipped, mark the order as 'shipped'.
     */
    public function create(array $data, int $userId): Shipment
    {
        $warehouseDocId = null;

        $shipment = DB::transaction(function () use ($data, $userId, &$warehouseDocId): Shipment {
            // Inside the transaction, and holding row locks, so the balance we
            // read is the balance we write against. See instructions/phase-1/03.
            $requestedPerVariant = $this->assertSufficientStock($data['items']);

            $shipmentDate = Carbon::parse($data['shipment_datetime']);

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
                $price     = (float) $itemData['price'];

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

            // vat_amount = round(subtotal x vat_rate, 2) — applied to the
            // DISCOUNTED subtotal (config('money.vat_applies_to')), computed
            // once here and frozen. 0.00 whenever vat_rate is 0, which is
            // every shipment today. See
            // instructions/phase-3/04-currency-vat-discount.md.
            $vatAmount = $this->round2(bcmul($subtotal, (string) $vatRate, 8));
            $shipment->update(['vat_amount' => $vatAmount]);

            // ── 4. Update order status if fully shipped ─────────────────────
            if ($shipment->order_id !== null) {
                $this->syncOrderShippedStatus($shipment->order_id);
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
            $sheet->setCellValue("D{$row}", $variant?->barcode_value ?? '');
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
        $price = ShipmentItem::whereHas(
            'shipment',
            fn ($q) => $q->where('client_id', $clientId)
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
