<!DOCTYPE html>
<html lang="uz">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>Warehouse Document #{{ $document->id }}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: DejaVu Sans, Arial, sans-serif;
            font-size: 12px;
            color: #1a1a1a;
            background: #fff;
        }

        .page {
            padding: 32px 36px;
        }

        /* ── Header ─────────────────────────────────────── */
        .brand {
            font-size: 22px;
            font-weight: bold;
            color: #1a3c5e;
            letter-spacing: 1px;
        }

        .invoice-title {
            font-size: 16px;
            font-weight: bold;
            color: #444;
            margin-top: 4px;
        }

        .header-meta {
            margin-top: 18px;
            width: 100%;
        }

        .header-meta table {
            width: 100%;
        }

        .header-meta td {
            vertical-align: top;
            padding: 0;
        }

        .meta-label {
            font-size: 10px;
            color: #888;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .meta-value {
            font-size: 13px;
            font-weight: bold;
            color: #1a1a1a;
            margin-top: 2px;
        }

        .meta-sub {
            font-size: 11px;
            color: #555;
            margin-top: 1px;
        }

        /* ── Divider ─────────────────────────────────────── */
        .divider {
            border: none;
            border-top: 2px solid #1a3c5e;
            margin: 20px 0;
        }

        /* ── Type badge ──────────────────────────────────── */
        .type-badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 4px;
            font-size: 11px;
            font-weight: bold;
            letter-spacing: 0.5px;
            text-transform: uppercase;
        }

        .type-in    { background-color: #dcfce7; color: #166534; }
        .type-out   { background-color: #fee2e2; color: #991b1b; }
        .type-return { background-color: #fef3c7; color: #92400e; }
        .type-adjustment { background-color: #ede9fe; color: #5b21b6; }

        /* ── Items Table ─────────────────────────────────── */
        .items-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 8px;
        }

        .items-table thead tr {
            background-color: #1a3c5e;
            color: #ffffff;
        }

        .items-table th {
            padding: 9px 10px;
            text-align: left;
            font-size: 11px;
            font-weight: bold;
            letter-spacing: 0.4px;
            text-transform: uppercase;
        }

        .items-table th.right,
        .items-table td.right {
            text-align: right;
        }

        .items-table td {
            padding: 8px 10px;
            font-size: 12px;
            border-bottom: 1px solid #e8e8e8;
            color: #2c2c2c;
        }

        .items-table tbody tr:nth-child(even) {
            background-color: #f7f9fc;
        }

        /* ── Total Row ───────────────────────────────────── */
        .total-row {
            margin-top: 12px;
            text-align: right;
        }

        .total-row table {
            margin-left: auto;
            border-collapse: collapse;
        }

        .total-row td {
            padding: 6px 10px;
            font-size: 13px;
        }

        .total-row .total-label {
            font-weight: bold;
            color: #444;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .total-row .total-value {
            font-weight: bold;
            font-size: 15px;
            color: #1a3c5e;
            min-width: 90px;
            text-align: right;
        }

        .total-row .total-border {
            border-top: 2px solid #1a3c5e;
        }

        /* ── Shipment section ────────────────────────────── */
        .shipment-box {
            margin-top: 20px;
            padding: 12px 14px;
            background-color: #fef3c7;
            border: 1px solid #f59e0b;
            border-radius: 4px;
        }

        .shipment-box-title {
            font-size: 13px;
            font-weight: bold;
            margin-bottom: 8px;
            color: #92400e;
        }

        .shipment-box table {
            width: 100%;
        }

        .shipment-box td {
            padding: 3px 0;
            font-size: 11px;
            border: none;
        }

        .shipment-box .sl {
            width: 30%;
            color: #78350f;
        }

        /* ── Notes ───────────────────────────────────────── */
        .notes-box {
            margin-bottom: 12px;
            padding: 8px 10px;
            background-color: #f8fafc;
            border-left: 3px solid #1a3c5e;
            font-size: 11px;
            color: #444;
        }

        /* ── Footer ─────────────────────────────────────── */
        .footer {
            margin-top: 36px;
            font-size: 10px;
            color: #aaa;
            text-align: center;
        }
    </style>
</head>
<body>
<div class="page">

    {{-- ── Brand & Title ────────────────────────────────── --}}
    <div class="brand">TGC Carpets</div>
    <div class="invoice-title">
        Omborxona hujjati #{{ $document->id }}
        &nbsp;
        <span style="margin-top: 12px;" class="type-badge type-{{ $document->type }}">{{ $docTypeLabel }}</span>
    </div>

    <div class="header-meta">
        <table>
            <tr>
                <td style="width: 50%;">
                    <div class="meta-label">Sana</div>
                    <div class="meta-value">
                        {{ $document->document_date?->format('d M Y') }}
                    </div>
                    <div class="meta-sub">
                        {{ $document->document_date?->format('H:i') }}
                    </div>
                </td>
                <td style="width: 50%;">
                    <div class="meta-label">Masul xodim</div>
                    <div class="meta-value">{{ $document->user->name ?? '—' }}</div>
                </td>
            </tr>
        </table>
    </div>

    <hr class="divider">

    {{-- ── Notes ───────────────────────────────────────── --}}
    @if($document->notes)
        <div class="notes-box">
            <strong>Izoh:</strong> {{ $document->notes }}
        </div>
    @endif

    {{-- ── Items Table ──────────────────────────────────── --}}
    <table class="items-table">
        <thead>
            <tr>
                <th style="width: 4%;">#</th>
                <th style="width: 19%;">Mahsulot</th>
                <th style="width: 11%;">Rang</th>
                <th style="width: 11%;">Tur</th>
                <th style="width: 11%;">Sifat</th>
                <th style="width: 11%;">O'lcham</th>
                <th class="right" style="width: 10%;">m² (dona)</th>
                <th class="right" style="width: 10%;">Miqdor</th>
                <th class="right" style="width: 13%;">Umumiy m²</th>
            </tr>
        </thead>
        <tbody>
            @php
                $grandTotalQty = 0;
                $grandTotalSqm = 0.0;
                $hasSqm = false;
            @endphp
            @foreach ($document->items as $index => $item)
                @php
                    $variant = $item->variant;
                    $product = $variant?->productColor?->product;
                    $quality = $product?->productQuality;
                    $type    = $product?->productType;
                    $color   = $variant?->productColor?->color;
                    $size    = $variant?->productSize;

                    $sizeLabel    = $size ? $size->length . ' × ' . $size->width : '—';
                    $sizePerUnit  = ($size && $size->length && $size->width)
                        ? number_format($size->length * $size->width / 10000, 4)
                        : null;
                    $sqm = ($size && $size->length && $size->width)
                        ? round($size->length * $size->width * $item->quantity / 10000, 4)
                        : null;

                    $grandTotalQty += $item->quantity;
                    if ($sqm !== null) {
                        $grandTotalSqm += $sqm;
                        $hasSqm = true;
                    }
                @endphp
                <tr>
                    <td>{{ $index + 1 }}</td>
                    <td>{{ $product?->name ?? '—' }}</td>
                    <td>{{ $color?->name ?? '—' }}</td>
                    <td>{{ $type?->type ?? '—' }}</td>
                    <td>{{ $quality?->quality_name ?? '—' }}</td>
                    <td>{{ $sizeLabel }}</td>
                    <td class="right">
                        @if($sizePerUnit !== null)
                            {{ $sizePerUnit }} m²
                        @else
                            —
                        @endif
                    </td>
                    <td class="right">{{ $item->quantity }}</td>
                    <td class="right">
                        @if($sqm !== null)
                            {{ number_format($sqm, 2) }} m²
                        @else
                            —
                        @endif
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>

    {{-- ── Totals ───────────────────────────────────────── --}}
    <div class="total-row">
        <table>
            <tr>
                <td class="total-label total-border">Jami dona</td>
                <td class="total-value total-border">{{ $grandTotalQty }}</td>
            </tr>
            @if($hasSqm)
            <tr>
                <td class="total-label">Jami m²</td>
                <td class="total-value">{{ number_format($grandTotalSqm, 2) }} m²</td>
            </tr>
            @endif
        </table>
    </div>

    {{-- ── Shipment Info (out-type only) ───────────────── --}}
    @if($shipmentInfo)
        <div class="shipment-box">
            <div class="shipment-box-title">YUK MA'LUMOTLARI</div>
            <table>
                <tr>
                    <td class="sl">Yuk chiqarish №:</td>
                    <td><strong>{{ $shipmentInfo['id'] }}</strong></td>
                </tr>
                <tr>
                    <td class="sl">Sana:</td>
                    <td>{{ $shipmentInfo['shipment_datetime'] }}</td>
                </tr>
                @if($shipmentInfo['client'])
                <tr>
                    <td class="sl">Mijoz:</td>
                    <td>{{ $shipmentInfo['client']['shop_name'] }}</td>
                </tr>
                <tr>
                    <td class="sl">Aloqa shaxs:</td>
                    <td>{{ $shipmentInfo['client']['contact_person'] }}</td>
                </tr>
                <tr>
                    <td class="sl">Hudud:</td>
                    <td>{{ $shipmentInfo['client']['region'] }}</td>
                </tr>
                @if($shipmentInfo['client']['phone'])
                <tr>
                    <td class="sl">Telefon:</td>
                    <td>{{ $shipmentInfo['client']['phone'] }}</td>
                </tr>
                @endif
                @endif
                @if($shipmentInfo['user'])
                <tr>
                    <td class="sl">Sotuv menejeri:</td>
                    <td>{{ $shipmentInfo['user']['name'] }}</td>
                </tr>
                @endif
                @if($shipmentInfo['notes'])
                <tr>
                    <td class="sl">Izoh:</td>
                    <td>{{ $shipmentInfo['notes'] }}</td>
                </tr>
                @endif
            </table>
        </div>
    @endif

    {{-- ── Footer ───────────────────────────────────────── --}}
    <div class="footer">
        Generated on {{ now()->format('d M Y, H:i') }} &nbsp;·&nbsp; TGC Carpets ERP
    </div>

</div>
</body>
</html>
