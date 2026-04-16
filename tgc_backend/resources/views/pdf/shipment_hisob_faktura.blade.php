<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <title>Hisob-faktura #{{ $shipment->id }}</title>
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

        .doc-title {
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
            min-width: 100px;
            text-align: right;
        }

        .total-row .total-border {
            border-top: 2px solid #1a3c5e;
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
        <div class="doc-title">Hisob-faktura #{{ $shipment->id }}</div>

        <div class="header-meta" style="margin-top: 18px;">
            <table>
                <tr>
                    <td style="width: 33%;">
                        <div class="meta-label">Sana</div>
                        <div class="meta-value">
                            {{ $shipment->shipment_datetime->format('d M Y') }}
                        </div>
                        <div class="meta-sub">
                            {{ $shipment->shipment_datetime->format('H:i') }}
                        </div>
                    </td>
                    <td style="width: 33%;">
                        <div class="meta-label">Mijoz</div>
                        <div class="meta-value">
                            {{ $shipment->client->shop_name ?? $shipment->client->contact_name }}
                        </div>
                        @if ($shipment->client->region)
                            <div class="meta-sub">{{ $shipment->client->region }}</div>
                        @endif
                    </td>
                    @if ($shipment->notes)
                        <td style="width: 34%;">
                            <div class="meta-label">Izoh</div>
                            <div class="meta-sub">{{ $shipment->notes }}</div>
                        </td>
                    @endif
                </tr>
            </table>
        </div>

        <hr class="divider">

        {{-- ── Items Table ──────────────────────────────────── --}}
        <table class="items-table">
            <thead>
                <tr>
                    <th style="width: 4%;">#</th>
                    <th style="width: 18%;">Mahsulot</th>
                    <th style="width: 14%;">Rang</th>
                    <th style="width: 14%;">Sifat</th>
                    <th style="width: 14%;">O'lcham (cm)</th>
                    <th class="right" style="width: 8%;">Miqdor</th>
                    <th class="right" style="width: 9%;">m²</th>
                    <th class="right" style="width: 10%;">Narx ($)</th>
                    <th class="right" style="width: 9%;">Jami ($)</th>
                </tr>
            </thead>
            <tbody>
                @php
                    $grandTotalSqm   = 0;
                    $grandTotalQty   = 0;
                    $grandTotalPrice = 0;
                @endphp
                @foreach ($shipment->items as $index => $item)
                    @php
                        $product = $item->variant?->productColor?->product;
                        $color   = $item->variant?->productColor?->color;
                        $quality = $product?->productQuality;
                        $size    = $item->variant?->productSize;
                        $unit    = $product?->unit ?? 'piece';
                        $qty     = $item->quantity;
                        $price   = (float) $item->price;

                        $sqm = ($size && $unit === 'm2')
                            ? round(($size->length * $size->width * $qty) / 10000, 4)
                            : 0;

                        $lineTotal = ($unit === 'm2' && $sqm > 0)
                            ? round($price * $sqm, 2)
                            : round($price * $qty, 2);

                        $grandTotalSqm   += $sqm;
                        $grandTotalQty   += $qty;
                        $grandTotalPrice += $lineTotal;
                    @endphp
                    <tr>
                        <td>{{ $index + 1 }}</td>
                        <td>{{ $product?->name ?? '—' }}</td>
                        <td>{{ $color?->color_name ?? '—' }}</td>
                        <td>{{ $quality?->quality_name ?? '—' }}</td>
                        <td>
                            @if ($size)
                                {{ $size->length }} × {{ $size->width }}
                            @else
                                —
                            @endif
                        </td>
                        <td class="right">{{ $qty }}</td>
                        <td class="right">
                            @if ($sqm > 0)
                                {{ number_format($sqm, 2) }}
                            @else
                                —
                            @endif
                        </td>
                        <td class="right">{{ number_format($price, 2) }}</td>
                        <td class="right">{{ number_format($lineTotal, 2) }}</td>
                    </tr>
                @endforeach
            </tbody>
        </table>

        {{-- ── Totals ───────────────────────────────────────── --}}
        <div class="total-row">
            <table>
                <tr>
                    <td class="total-label">Umumiy dona</td>
                    <td class="total-value">{{ number_format($grandTotalQty, 0) }}</td>
                </tr>
                @if ($grandTotalSqm > 0)
                <tr>
                    <td class="total-label">Umumiy m²</td>
                    <td class="total-value">{{ number_format($grandTotalSqm, 2) }} m²</td>
                </tr>
                @endif
                <tr>
                    <td class="total-label total-border">Jami summa</td>
                    <td class="total-value total-border">$ {{ number_format($grandTotalPrice, 2) }}</td>
                </tr>
            </table>
        </div>

        {{-- ── Footer ───────────────────────────────────────── --}}
        <div class="footer">
            Generated on {{ now()->format('d M Y, H:i') }} &nbsp;·&nbsp; TGC Carpets ERP
        </div>

    </div>
</body>

</html>
