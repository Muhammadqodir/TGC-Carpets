<?php

namespace App\Http\Controllers;

use App\Models\Shipment;
use App\Models\WarehouseDocument;
use App\Services\WarehousePdfService;
use Illuminate\View\View;

/**
 * Dev-only controller for previewing PDF Blade templates in the browser.
 * Routes are registered only outside production (see web.php).
 */
class PdfPreviewController extends Controller
{
    public function __construct(
        private readonly WarehousePdfService $pdfService,
    ) {}

    /**
     * Preview: pdf/warehouse_document
     * GET /pdf-preview/warehouse-document/{id?}
     */
    public function warehouseDocument(?int $id = null): View
    {
        $document = $id
            ? WarehouseDocument::findOrFail($id)
            : WarehouseDocument::first();

        abort_if(! $document, 404, 'No warehouse documents found. Seed some data first.');

        $document->loadMissing([
            'user',
            'items.variant.productColor.product.productType',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.color',
            'items.variant.productSize',
        ]);

        $shipmentInfo = $document->isOutgoing()
            ? $this->pdfService->resolveShipmentInfo($document)
            : null;

        return view('pdf.warehouse_document', [
            'document'     => $document,
            'docTypeLabel' => $this->pdfService->resolveDocumentTypeName($document->type),
            'shipmentInfo' => $shipmentInfo,
        ]);
    }

    /**
     * Preview: pdf/shipment_invoice (Yuk xati)
     * GET /pdf-preview/shipment-invoice/{id?}
     */
    public function shipmentInvoice(?int $id = null): View
    {
        $shipment = $this->loadShipment($id);

        return view('pdf.shipment_invoice', [
            'shipment' => $shipment,
        ]);
    }

    /**
     * Preview: pdf/shipment_hisob_faktura (Hisob-faktura)
     * GET /pdf-preview/shipment-hisob-faktura/{id?}
     */
    public function shipmentHisobFaktura(?int $id = null): View
    {
        $shipment = $this->loadShipment($id);

        return view('pdf.shipment_hisob_faktura', [
            'shipment' => $shipment,
        ]);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function loadShipment(?int $id): Shipment
    {
        $shipment = $id
            ? Shipment::findOrFail($id)
            : Shipment::first();

        abort_if(! $shipment, 404, 'No shipments found. Seed some data first.');

        $shipment->loadMissing([
            'client',
            'user',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.product.productType',
            'items.variant.productColor.color',
            'items.variant.productSize',
        ]);

        return $shipment;
    }
}
