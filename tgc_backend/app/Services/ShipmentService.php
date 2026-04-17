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

        $this->generateAndStoreInvoice($shipment);
        $this->generateAndStoreHisobFaktura($shipment);

        // Generate warehouse document PDF after the transaction so all items are committed
        if ($warehouseDocId !== null) {
            $warehouseDoc = WarehouseDocument::findOrFail($warehouseDocId);
            $pdfPath = $this->warehousePdfService->generatePdf($warehouseDoc);
            $warehouseDoc->update(['pdf_path' => $pdfPath]);
        }

        return $shipment->refresh()->load([
            'client',
            'user',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.color',
            'items.variant.productSize',
        ]);
    }

    /**
     * Generate the shipment invoice PDF, persist it to storage, and update
     * the shipment record with the stored path.
     */
    public function generateAndStoreInvoice(Shipment $shipment): void
    {
        $shipment->loadMissing([
            'client',
            'items.variant.productColor.product.productQuality',
            'items.variant.productSize',
        ]);

        $pdf = Pdf::loadView('pdf.shipment_invoice', ['shipment' => $shipment])
            ->setPaper('a4', 'portrait')->setOptions(['dpi' => 130, 'defaultFont' => 'sans-serif']);

        $relativePath = 'shipments/invoices/invoice_' . $shipment->id . '.pdf';

        Storage::disk('public')->put($relativePath, $pdf->output());

        $shipment->update(['pdf_path' => $relativePath]);
    }

    /**
     * Generate the hisob-faktura (price invoice) PDF with price_per_unit and
     * total price columns, persist it, and update invoice_path on the shipment.
     */
    public function generateAndStoreHisobFaktura(Shipment $shipment): void
    {
        $shipment->loadMissing([
            'client',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.color',
            'items.variant.productSize',
        ]);

        $pdf = Pdf::loadView('pdf.shipment_hisob_faktura', ['shipment' => $shipment])
            ->setPaper('a4', 'portrait')->setOptions(['dpi' => 130, 'defaultFont' => 'sans-serif']);

        $relativePath = 'shipments/hisob_faktura/faktura_' . $shipment->id . '.pdf';

        Storage::disk('public')->put($relativePath, $pdf->output());

        $shipment->update(['invoice_path' => $relativePath]);
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
            ->whereIn('movement_type', [WarehouseDocument::TYPE_IN, WarehouseDocument::TYPE_RETURN])
            ->sum('quantity');

        $out = (clone $base)
            ->where('movement_type', WarehouseDocument::TYPE_OUT)
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
