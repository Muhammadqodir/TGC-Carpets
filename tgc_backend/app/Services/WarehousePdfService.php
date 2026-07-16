<?php

namespace App\Services;

use App\Models\WarehouseDocument;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class WarehousePdfService
{
    /**
     * Generate and store a PDF for the given warehouse document.
     * Returns the relative storage path.
     */
    public function generatePdf(WarehouseDocument $document): string
    {
        $document->loadMissing([
            'user',
            'items.variant.productColor.product.productType',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.color',
            'items.variant.productSize',
            'items.variant.productEdge',
        ]);

        $shipmentInfo = $document->isOutgoing() ? $this->resolveShipmentInfo($document) : null;

        $pdf = Pdf::loadView('pdf.warehouse_document', [
            'document'     => $document,
            'docTypeLabel' => $this->resolveDocumentTypeName($document->type, $document->direction),
            'shipmentInfo' => $shipmentInfo,
        ])->setPaper('a4', 'portrait')->setOptions(['dpi' => 130, 'defaultFont' => 'sans-serif']);

        $filename = "doc_{$document->id}_{$document->uuid}.pdf";
        $path = "warehouse-documents/pdfs/{$filename}";

        Storage::disk('public')->put($path, $pdf->output());

        return $path;
    }

    /**
     * Get shipment information if this warehouse document's items are linked to a shipment.
     */
    public function resolveShipmentInfo(WarehouseDocument $document): ?array
    {
        $shipmentItemId = DB::table('warehouse_document_items')
            ->where('warehouse_document_id', $document->id)
            ->where('source_type', 'shipment_item')
            ->value('source_id');

        if (! $shipmentItemId) {
            return null;
        }

        $shipment = DB::table('shipments')
            ->join('shipment_items', 'shipment_items.shipment_id', '=', 'shipments.id')
            ->where('shipment_items.id', $shipmentItemId)
            ->select('shipments.*')
            ->first();

        if (! $shipment) {
            return null;
        }

        $client = DB::table('clients')->find($shipment->client_id);
        $user   = DB::table('users')->find($shipment->user_id);

        return [
            'id'                => $shipment->id,
            'shipment_datetime' => $shipment->shipment_datetime,
            'client'            => $client ? [
                'shop_name'      => $client->shop_name,
                'contact_person' => $client->contact_name,
                'phone'          => $client->phone,
                'region'         => $client->region,
            ] : null,
            'user'  => $user ? ['name' => $user->name] : null,
            'notes' => $shipment->notes,
        ];
    }

    /**
     * Get Uzbek label for a document type. For an adjustment, appends the
     * direction so the printed document states in words which way stock
     * moved — the total row's sign (see warehouse_document.blade.php)
     * says the same thing numerically. See
     * instructions/phase-3/05-signed-adjustment-documents.md.
     */
    public function resolveDocumentTypeName(string $type, ?string $direction = null): string
    {
        $label = match ($type) {
            'in'         => 'KIRIM',
            'out'        => 'CHIQIM',
            'return'     => 'QAYTISH',
            'adjustment' => 'TUZATISH',
            default      => strtoupper($type),
        };

        if ($type === 'adjustment') {
            $label .= $direction === 'out' ? ' (KAMAYTIRISH)' : ' (KO\'PAYTIRISH)';
        }

        return $label;
    }
}
