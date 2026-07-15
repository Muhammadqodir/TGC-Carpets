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

            // ── 1. Shipment header ──────────────────────────────────────────
            $shipment = Shipment::create([
                'client_id'          => $data['client_id'],
                'user_id'            => $userId,
                'order_id'           => $data['order_id'] ?? null,
                'shipment_datetime'  => $shipmentDate,
                'notes'              => $data['notes'] ?? null,
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
                ]);

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
            }

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
     */
    public function getLastPrice(int $variantId, int $clientId): ?float
    {
        $price = ShipmentItem::whereHas(
            'shipment',
            fn ($q) => $q->where('client_id', $clientId)
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
