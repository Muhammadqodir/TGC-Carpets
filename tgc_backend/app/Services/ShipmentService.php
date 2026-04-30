<?php

namespace App\Services;

use App\Models\Order;
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
        $this->assertSufficientStock($data['items']);

        $warehouseDocId = null;

        $shipment = DB::transaction(function () use ($data, $userId, &$warehouseDocId): Shipment {
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
                'items.variant:id,product_color_id,product_size_id',
                'items.variant.productColor:id,product_id,color_id',
                'items.variant.productColor.product:id,name,product_quality_id',
                'items.variant.productColor.product.productQuality:id,name',
                'items.variant.productSize:id,name',
            ])
            ->findOrFail($shipmentId);

        $pdf = Pdf::loadView('pdf.shipment_invoice', ['shipment' => $shipment])
            ->setPaper('a4', 'portrait')
            ->setOptions([
                'dpi' => 96, // Reduced DPI to save memory
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
                'items.variant:id,product_color_id,product_size_id',
                'items.variant.productColor:id,product_id,color_id',
                'items.variant.productColor.product:id,name,product_quality_id',
                'items.variant.productColor.product.productQuality:id,name',
                'items.variant.productColor.color:id,name',
                'items.variant.productSize:id,name',
            ])
            ->findOrFail($shipmentId);

        $pdf = Pdf::loadView('pdf.shipment_hisob_faktura', ['shipment' => $shipment])
            ->setPaper('a4', 'portrait')
            ->setOptions([
                'dpi' => 96, // Reduced DPI to save memory
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

    private function assertSufficientStock(array $items): void
    {
        $errors = [];

        foreach ($items as $index => $itemData) {
            $variantId    = (int) $itemData['product_variant_id'];
            $requested    = (int) $itemData['quantity'];
            $currentStock = $this->getStock($variantId);

            if ($currentStock < $requested) {
                $errors["items.{$index}.quantity"] = [
                    "Insufficient stock for variant ID {$variantId}. Available: {$currentStock}, Requested: {$requested}.",
                ];
            }
        }

        if (! empty($errors)) {
            throw ValidationException::withMessages($errors);
        }
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
