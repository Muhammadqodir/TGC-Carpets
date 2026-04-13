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
        // Eager-load all needed relationships
        $document->load([
            'user',
            'items.variant.productColor.product.productType',
            'items.variant.productColor.product.productQuality',
            'items.variant.productColor.color',
            'items.variant.productSize',
        ]);

        // Check if this is an outgoing document related to a shipment
        $shipmentInfo = null;
        if ($document->isOutgoing()) {
            $shipmentInfo = $this->getShipmentInfo($document);
        }

        $html = $this->buildHtml($document, $shipmentInfo);

        $pdf = Pdf::loadHTML($html)
            ->setPaper('a4', 'portrait')
            ->setOption('isHtml5ParserEnabled', true)
            ->setOption('isPhpEnabled', true)
            ->setOption('isRemoteEnabled', false)
            ->setOption('compress', 1);

        $filename = "doc_{$document->id}_{$document->uuid}.pdf";
        $path = "warehouse-documents/pdfs/{$filename}";

        Storage::disk('public')->put($path, $pdf->output());

        return $path;
    }

    /**
     * Get shipment information if this warehouse document's items are linked to a shipment.
     */
    private function getShipmentInfo(WarehouseDocument $document): ?array
    {
        // Look for a shipment_item linked via warehouse_document_items source
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
            'id'                 => $shipment->id,
            'shipment_datetime'  => $shipment->shipment_datetime,
            'client'             => $client ? [
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
     * Build the HTML content for the PDF.
     */
    private function buildHtml(WarehouseDocument $document, ?array $shipmentInfo): string
    {
        $docType = $this->getDocumentTypeName($document->type);
        $userName = $document->user->name ?? 'N/A';
        $docDate = $document->document_date?->format('d.m.Y  H:i') ?? '';
        $notes = $document->notes ?? '';

        // Calculate totals
        $totalQty = $document->items->sum('quantity');
        $totalSqm = 0.0;
        $hasSqm = false;

        foreach ($document->items as $item) {
            $size = $item->variant->productSize;
            if ($size && $size->length && $size->width) {
                $sqm = ($size->length * $size->width * $item->quantity) / 10000.0;
                $totalSqm += $sqm;
                $hasSqm = true;
            }
        }

        $totalSqmFormatted = $this->formatSqm($totalSqm);

        // Build table rows
        $rows = '';
        foreach ($document->items as $index => $item) {
            $variant = $item->variant;
            $productName = $variant->productColor->product->name ?? '—';
            $quality = $variant->productColor->product->productQuality->quality_name ?? '—';
            $type = $variant->productColor->product->productType->type ?? '—';
            $color = $variant->productColor->color->name ?? '—';

            $size = $variant->productSize;
            $sizeLabel = $size ? "{$size->length}x{$size->width}" : '—';
            $squareMeters = $size ? "{($size->length * $size->width)}" : '—';

            $sqm = null;
            if ($size && $size->length && $size->width) {
                $sqm = ($size->length * $size->width * $item->quantity) / 10000.0;
            }
            $sqmFormatted = $sqm !== null ? $sqm : '—';

            $bgColor = ($index % 2 === 0) ? '#ffffff' : '#f3f4f6';
            $num = $index + 1;

            $rows .= "
                <tr style=\"background-color: {$bgColor};\">
                    <td style=\"padding: 6px; font-size: 9px;\">{$num}</td>
                    <td style=\"padding: 6px; font-size: 9px;\">{$productName}</td>
                    <td style=\"padding: 6px; font-size: 9px;\">{$quality}</td>
                    <td style=\"padding: 6px; font-size: 9px;\">{$type}</td>
                    <td style=\"padding: 6px; font-size: 9px;\">{$color}</td>
                    <td style=\"padding: 6px; font-size: 9px;\">{$sizeLabel}</td>
                    <td style=\"padding: 6px; font-size: 9px;\">{$squareMeters}</td>
                    <td style=\"padding: 6px; font-size: 9px; font-weight: bold;\">{$item->quantity}</td>
                    <td style=\"padding: 6px; font-size: 9px; font-weight: bold;\">{$sqmFormatted}</td>
                </tr>
            ";
        }

        // Build shipment info section if available
        $shipmentSection = '';
        if ($shipmentInfo) {
            $shipmentDate  = date('d.m.Y  H:i', strtotime($shipmentInfo['shipment_datetime']));
            $clientName    = $shipmentInfo['client']['shop_name'] ?? 'N/A';
            $clientRegion  = $shipmentInfo['client']['region'] ?? 'N/A';
            $clientPhone   = $shipmentInfo['client']['phone'] ?? '';
            $clientContact = $shipmentInfo['client']['contact_person'] ?? '';

            $shipmentSection = "
                <div style=\"margin-top: 20px; padding: 12px; background-color: #fef3c7; border: 1px solid #f59e0b; border-radius: 4px;\">
                    <div style=\"font-size: 13px; font-weight: bold; margin-bottom: 8px;\">YETKAZIB BERISH MA'LUMOTLARI</div>
                    <table style=\"width: 100%; font-size: 11px;\">
                        <tr>
                            <td style=\"padding: 3px 0; width: 30%;\">Yetkazib berish №:</td>
                            <td style=\"padding: 3px 0;\"><strong>{$shipmentInfo['id']}</strong></td>
                        </tr>
                        <tr>
                            <td style=\"padding: 3px 0;\">Sana:</td>
                            <td style=\"padding: 3px 0;\">{$shipmentDate}</td>
                        </tr>
                        <tr>
                            <td style=\"padding: 3px 0;\">Mijoz:</td>
                            <td style=\"padding: 3px 0;\">{$clientContact}/{$clientRegion}</td>
                        </tr>
                    </table>
                </div>
            ";
        }

        // Build full HTML
        $html = "
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset=\"UTF-8\">
                <style>
                    body {
                        font-family: sans-serif;
                        font-size: 11px;
                        margin: 0;
                        padding: 0;
                    }
                    .title {
                        font-size: 16px;
                        font-weight: bold;
                        text-align: center;
                        margin-bottom: 6px;
                    }
                    .subtitle {
                        font-size: 13px;
                        font-weight: bold;
                        text-align: center;
                        margin-bottom: 4px;
                    }
                    .divider {
                        border-top: 1.5px solid #000;
                        margin: 8px 0;
                    }
                    .meta {
                        display: table;
                        width: 100%;
                        margin-bottom: 16px;
                    }
                    .meta-row {
                        display: table-row;
                    }
                    .meta-cell {
                        display: table-cell;
                        padding: 2px 0;
                    }
                    .meta-right {
                        text-align: right;
                    }
                    table {
                        width: 100%;
                        border-collapse: collapse;
                        margin-bottom: 12px;
                    }
                    th {
                        background-color: #d1d5db;
                        padding: 6px;
                        font-size: 11px;
                        font-weight: bold;
                        text-align: left;
                        border: 0.5px solid #9ca3af;
                    }
                    td {
                        border: 0.5px solid #9ca3af;
                        text-align: left;
                    }
                    .totals {
                        text-align: right;
                        font-size: 11px;
                        font-weight: bold;
                    }
                </style>
            </head>
            <body>
                <div class=\"title\">TGC CARPETS</div>
                <div class=\"subtitle\">OMBORGA {$docType} HUJJATI</div>
                <div class=\"subtitle\">№ {$document->id}</div>
                <div class=\"divider\"></div>

                <div class=\"meta\">
                    <div class=\"meta-row\">
                        <div class=\"meta-cell\">Masul xodim: {$userName}</div>
                        <div class=\"meta-cell meta-right\">Sana: {$docDate}</div>
                    </div>
                </div>
        ";

        if ($notes) {
            $html .= "<div style=\"margin-bottom: 8px;\">Izoh: {$notes}</div>";
        }

        $html .= "
                <table>
                    <thead>
                        <tr>
                            <th style=\"width: 30px;\">#</th>
                            <th>Mahsulot</th>
                            <th>Sifat</th>
                            <th>Turi</th>
                            <th>Rangi</th>
                            <th>O'lcham</th>
                            <th>m²</th>
                            <th style=\"width: 60px;\">Miqdor</th>
                            <th style=\"width: 85px;\">Umumiy(m²)</th>
                        </tr>
                    </thead>
                    <tbody>
                        {$rows}
                    </tbody>
                </table>

                <div class=\"totals\">
                    <div>Jami: {$totalQty} dona</div>
        ";

        if ($hasSqm) {
            $html .= "<div>Jami: {$totalSqmFormatted}</div>";
        }

        $html .= "
                </div>

                {$shipmentSection}
            </body>
            </html>
        ";

        return $html;
    }

    /**
     * Get Uzbek document type name.
     */
    private function getDocumentTypeName(string $type): string
    {
        return match ($type) {
            'in' => 'KIRIM',
            'out' => 'CHIQIM',
            'return' => 'QAYTISH',
            'adjustment' => 'TUZATISH',
            default => strtoupper($type),
        };
    }

    /**
     * Format square meters value (suppress decimals when zero).
     */
    private function formatSqm(float $value): string
    {
        if ($value == (int) $value) {
            return (int) $value . ' m²';
        }

        return number_format($value, 2, '.', '') . ' m²';
    }
}
