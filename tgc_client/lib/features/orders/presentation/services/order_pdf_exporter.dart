import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/order_entity.dart';
import '../../domain/entities/order_item_entity.dart';

/// Exports an [OrderEntity] to a print-ready landscape PDF that mirrors the
/// order_items_sheet matrix layout:
///
///  • Rows    = unique (productColorId) combinations
///  • Columns = sizes (grouped by product type, colour-coded)
///  • Cells   = ordered quantity
///
/// Horizontal pagination: if the number of sizes exceeds what fits on one
/// page width they are split into multiple [pw.MultiPage] blocks.
/// Vertical overflow within each block is handled automatically by [pw.MultiPage],
/// which repeats the type+column header row at the top of every page.
class OrderPdfExporter {
  // ─── Colours ─────────────────────────────────────────────────────────────
  static final _primary      = PdfColor.fromHex('1565C0');
  static final _primaryLight = PdfColor.fromHex('E3F2FD');
  static final _successBg    = PdfColor.fromHex('E8F5E9');
  static final _grayRow      = PdfColor.fromHex('F5F5F5');
  static final _disabledBg   = PdfColor.fromHex('EEEEEE');
  static final _textSec      = PdfColor.fromHex('9E9E9E');
  static final _borderColor  = PdfColor.fromHex('BDBDBD');
  static final _infoText     = PdfColor.fromHex('B3D4F5');

  static final _typePalette = <PdfColor>[
    PdfColor.fromHex('BBDEFB'), // blue-100
    PdfColor.fromHex('C8E6C9'), // green-100
    PdfColor.fromHex('FFE0B2'), // orange-100
    PdfColor.fromHex('E1BEE7'), // purple-100
    PdfColor.fromHex('B2DFDB'), // teal-100
    PdfColor.fromHex('F8BBD0'), // pink-100
  ];

  // ─── Layout constants (pt) ───────────────────────────────────────────────
  static const _kMargin  = 14.0;
  static const _kColNum  = 20.0;  // # column
  static const _kColMeta = 130.0; // product / colour / quality
  static const _kColSize = 40.8;  // each size column
  static const _kColTot  = 52.0;  // Jami m²
  static const _kRowH    = 22.0;  // data row height (fits 2 lines at 7pt)
  static const _kHdrH    = 22.0;  // column-header row
  static const _kTypeH   = 13.0;  // type-label row

  static const _fsTitle = 9.0;
  static const _fsMeta  = 7.0;
  static const _fsTh    = 7.5;
  static const _fsTd    = 7.5;
  static const _fsType  = 6.5;

  // ─── Entry point ─────────────────────────────────────────────────────────
  Future<Uint8List> export(OrderEntity order) async {
    final doc       = pw.Document(title: 'Buyurtma #${order.id}', author: 'TGC Carpets');
    final landscape = PdfPageFormat.a4.landscape;

    // ── Matrix pre-computation ──────────────────────────────────────────────
    // Row keys: unique productColorId, preserving insertion order
    final rowKeys   = <int>[];
    final seenColor = <int>{};
    for (final item in order.items) {
      if (seenColor.add(item.productColorId)) rowKeys.add(item.productColorId);
    }

    // Size columns: unique productSizeId, preserving insertion order
    final sizeIds  = <int>[];
    final seenSize = <int>{};
    for (final item in order.items) {
      if (item.productSizeId != null && seenSize.add(item.productSizeId!)) {
        sizeIds.add(item.productSizeId!);
      }
    }

    // (colorId, sizeId) → item
    final cellMap = <(int, int), OrderItemEntity>{};
    for (final item in order.items) {
      if (item.productSizeId != null) {
        cellMap[(item.productColorId, item.productSizeId!)] = item;
      }
    }

    // Representative item per colorId (product / colour / quality meta)
    final rowMeta = <int, OrderItemEntity>{};
    for (final item in order.items) rowMeta.putIfAbsent(item.productColorId, () => item);

    // Sort product rows: by productTypeId, then product name, then colour name
    rowKeys.sort((a, b) {
      final ma = rowMeta[a];
      final mb = rowMeta[b];
      final cType = (ma?.productTypeId ?? 0).compareTo(mb?.productTypeId ?? 0);
      if (cType != 0) return cType;
      final cName = (ma?.productName ?? '').compareTo(mb?.productName ?? '');
      if (cName != 0) return cName;
      return (ma?.colorName ?? '').compareTo(mb?.colorName ?? '');
    });

    // Representative item per sizeId (label + sqm denominator)
    final sizeMeta = <int, OrderItemEntity>{};
    for (final item in order.items) {
      if (item.productSizeId != null) sizeMeta.putIfAbsent(item.productSizeId!, () => item);
    }

    // Sort size columns: by productTypeId, then width, then length
    sizeIds.sort((a, b) {
      final ma = sizeMeta[a];
      final mb = sizeMeta[b];
      final cType = (ma?.productTypeId ?? 0).compareTo(mb?.productTypeId ?? 0);
      if (cType != 0) return cType;
      final cW = (ma?.sizeWidth ?? 0).compareTo(mb?.sizeWidth ?? 0);
      if (cW != 0) return cW;
      return (ma?.sizeLength ?? 0).compareTo(mb?.sizeLength ?? 0);
    });

    // typeId → global size indices (insertion-order)
    final typeGroups = <int, List<int>>{};
    for (var i = 0; i < sizeIds.length; i++) {
      final typeId = sizeMeta[sizeIds[i]]?.productTypeId ?? 0;
      (typeGroups[typeId] ??= []).add(i);
    }

    // typeId → palette index
    final typeColorMap = <int, int>{};
    var tci = 0;
    for (final typeId in typeGroups.keys) typeColorMap[typeId] = tci++ % _typePalette.length;

    // typeId → display name
    final typeNames = <int, String>{};
    for (final item in order.items) {
      if (item.productTypeId != null) typeNames[item.productTypeId!] = item.productTypeName ?? 'Tur';
    }

    // ── Horizontal pagination ───────────────────────────────────────────────
    final availW    = landscape.availableWidth - _kMargin * 2;
    final fixedW    = _kColNum + _kColMeta + _kColTot;
    final maxSzPage = ((availW - fixedW) / _kColSize).floor().clamp(1, 999) + 3;

    final sizeChunks = <List<int>>[];
    if (sizeIds.isEmpty) {
      sizeChunks.add([]);
    } else {
      for (var i = 0; i < sizeIds.length; i += maxSzPage) {
        sizeChunks.add(sizeIds.sublist(i, (i + maxSzPage).clamp(0, sizeIds.length)));
      }
    }

    final totalChunks = sizeChunks.length;

    // ── Build all chunk content into a single MultiPage ─────────────────────
    final buildWidgets = <pw.Widget>[];

    for (var ci = 0; ci < totalChunks; ci++) {
      final chunk = sizeChunks[ci];

      // Chunk-local type groups: typeId → chunk-local column indices
      final chunkTypeGroups = <int, List<int>>{};
      for (var j = 0; j < chunk.length; j++) {
        final typeId = sizeMeta[chunk[j]]?.productTypeId ?? 0;
        (chunkTypeGroups[typeId] ??= []).add(j);
      }

      // Only include product rows that have at least one quantity in this chunk
      final chunkRowKeys = rowKeys
          .where((colorId) => chunk.any((sizeId) => cellMap[(colorId, sizeId)] != null))
          .toList();

      // Spacer between consecutive blocks
      if (ci > 0) buildWidgets.add(pw.SizedBox(height: 8));

      // Chunk table: type row + col header row repeated on overflow (headerCount: 2)
      buildWidgets.add(_buildChunkTable(
        chunkRowKeys:    chunkRowKeys,
        rowMeta:         rowMeta,
        chunk:           chunk,
        cellMap:         cellMap,
        sizeMeta:        sizeMeta,
        chunkTypeGroups: chunkTypeGroups,
        typeColorMap:    typeColorMap,
        typeNames:       typeNames,
      ));

      // Totals rows
      buildWidgets.add(_totalsRow(
        rowKeys:         chunkRowKeys,
        chunk:           chunk,
        cellMap:         cellMap,
        sizeMeta:        sizeMeta,
        chunkTypeGroups: chunkTypeGroups,
        typeColorMap:    typeColorMap,
        label:           'JAMI (dona)',
        valueFn: (sizeId, colorIds) {
          int sum = 0;
          for (final c in colorIds) sum += cellMap[(c, sizeId)]?.quantity ?? 0;
          return '$sum';
        },
        totalFn: (colorIds, chunkSizes) {
          double t = 0;
          for (final c in colorIds) {
            for (final s in chunkSizes) {
              final it = cellMap[(c, s)];
              if (it != null && it.sizeLength != null && it.sizeWidth != null) {
                t += it.sizeLength! * it.sizeWidth! * it.quantity / 10000.0;
              }
            }
          }
          return t.toStringAsFixed(2);
        },
        topThick: true,
      ));
      buildWidgets.add(_totalsRow(
        rowKeys:         chunkRowKeys,
        chunk:           chunk,
        cellMap:         cellMap,
        sizeMeta:        sizeMeta,
        chunkTypeGroups: chunkTypeGroups,
        typeColorMap:    typeColorMap,
        label:           'Jami m²',
        valueFn: (sizeId, colorIds) {
          final m = sizeMeta[sizeId];
          if (m?.sizeLength == null || m?.sizeWidth == null) return '—';
          double sum = 0;
          for (final c in colorIds) {
            final it = cellMap[(c, sizeId)];
            if (it != null) sum += m!.sizeLength! * m.sizeWidth! * it.quantity / 10000.0;
          }
          return sum.toStringAsFixed(2);
        },
        totalFn: (colorIds, chunkSizes) {
          double t = 0;
          for (final c in colorIds) {
            for (final s in chunkSizes) {
              final it = cellMap[(c, s)];
              final m  = sizeMeta[s];
              if (it != null && m?.sizeLength != null && m?.sizeWidth != null) {
                t += m!.sizeLength! * m.sizeWidth! * it.quantity / 10000.0;
              }
            }
          }
          return t.toStringAsFixed(2);
        },
        topThick: false,
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: landscape,
        margin:     pw.EdgeInsets.all(_kMargin),
        header: (ctx) => _pageHeader(order: order),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 3),
            child: pw.Text(
              'Sahifa ${ctx.pageNumber}'
              '${ctx.pagesCount > 0 ? ' / ${ctx.pagesCount}' : ''}',
              style: pw.TextStyle(fontSize: 6.5, color: _textSec),
            ),
          ),
        ),
        build: (ctx) => buildWidgets,
      ),
    );

    return doc.save();
  }

  // ─── Page header: info strip ─────────────────────────────────────────────
  pw.Widget _pageHeader({required OrderEntity order}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Info strip ────────────────────────────────────────────────────
        pw.Container(
          decoration: pw.BoxDecoration(
            color:        _primary,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BUYURTMA #${order.id}  |  TGC CARPETS',
                      style: pw.TextStyle(
                        fontSize:   _fsTitle,
                        fontWeight: pw.FontWeight.bold,
                        color:      PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Wrap(
                      spacing: 14,
                      runSpacing: 1,
                      children: [
                        _metaChip('Mijoz',  '${order.clientShopName ?? '—'} / ${order.clientRegion ?? '—'}'),
                        _metaChip('Sana',   _fmtDate(order.orderDate)),
                        _metaChip('Xodim',  order.userName),
                        _metaChip('Holat',  _statusLabel(order.status)),
                        _metaChip('Jami',   '${order.totalQuantity} dona  |  ${order.totalSqm.toStringAsFixed(2)} m²'),
                      ],
                    ),
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Izoh: ${order.notes!}',
                        style: pw.TextStyle(fontSize: 6.5, color: _infoText),
                        maxLines:  1,
                        overflow:  pw.TextOverflow.clip,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
      ],
    );
  }

  pw.Widget _metaChip(String label, String value) => pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
            text:  '$label: ',
            style: pw.TextStyle(fontSize: _fsMeta, color: _infoText, fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(
            text:  value,
            style: pw.TextStyle(fontSize: _fsMeta, color: PdfColors.white),
          ),
        ]),
      );

  // ─── Chunk table (type row + col header row + data rows) ────────────────────
  // The type-label row and col-header row use repeat:true so they are
  // automatically reprinted at the top of each new page when this table overflows.
  pw.Widget _buildChunkTable({
    required List<int> chunkRowKeys,
    required Map<int, OrderItemEntity> rowMeta,
    required List<int> chunk,
    required Map<(int, int), OrderItemEntity> cellMap,
    required Map<int, OrderItemEntity> sizeMeta,
    required Map<int, List<int>> chunkTypeGroups,
    required Map<int, int> typeColorMap,
    required Map<int, String> typeNames,
  }) {
    final typeByJ  = <int, int>{};
    final firstByT = <int, int>{};
    for (final e in chunkTypeGroups.entries) {
      for (final j in e.value) typeByJ[j] = e.key;
      if (e.value.isNotEmpty) firstByT[e.key] = e.value.first;
    }

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(_kColNum),
      1: const pw.FixedColumnWidth(_kColMeta),
      for (var j = 0; j < chunk.length; j++)
        j + 2: const pw.FixedColumnWidth(_kColSize),
      chunk.length + 2: const pw.FixedColumnWidth(_kColTot),
    };

    // Row 0: type-label row
    final typeRowCells = <pw.Widget>[
      _tc(text: '', height: _kTypeH, bg: _primaryLight),
      _tc(text: '', height: _kTypeH, bg: _primaryLight),
    ];
    for (var j = 0; j < chunk.length; j++) {
      final typeId  = typeByJ[j] ?? 0;
      final bg      = _typePalette[typeColorMap[typeId] ?? 0];
      final isFirst = firstByT[typeId] == j;
      typeRowCells.add(_tc(
        text:      isFirst ? (typeNames[typeId] ?? 'Tur #$typeId') : '',
        height:    _kTypeH,
        bg:        bg,
        fg:        isFirst ? _primary : null,
        bold:      isFirst,
        fontSize:  _fsType,
        thickLeft: isFirst,
      ));
    }
    typeRowCells.add(_tc(text: '', height: _kTypeH, bg: _primaryLight));

    // Row 1: column-header row
    final colHdrCells = <pw.Widget>[
      _tc(text: '#',                             height: _kHdrH, bg: _primary, fg: PdfColors.white, bold: true, fontSize: _fsTh),
      _tc(text: 'Mahsulot / Rang\nSifat / Tur', height: _kHdrH, bg: _primary, fg: PdfColors.white, bold: true, fontSize: _fsTh, align: pw.TextAlign.left),
    ];
    for (var j = 0; j < chunk.length; j++) {
      final m      = sizeMeta[chunk[j]];
      final label  = (m?.sizeWidth != null && m?.sizeLength != null)
          ? '${m!.sizeWidth}×${m.sizeLength}'
          : "O'lcham ${j + 1}";
      final typeId = typeByJ[j] ?? 0;
      final bg     = _typePalette[typeColorMap[typeId] ?? 0];
      colHdrCells.add(_tc(
        text:      label,
        height:    _kHdrH,
        bg:        bg,
        fg:        _primary,
        bold:      true,
        fontSize:  _fsTh,
        thickLeft: firstByT[typeId] == j,
      ));
    }
    colHdrCells.add(_tc(text: 'Jami m²', height: _kHdrH, bg: _primary, fg: PdfColors.white, bold: true, fontSize: _fsTh));

    // Data rows
    final tableRows = <pw.TableRow>[
      pw.TableRow(children: typeRowCells, repeat: true),
      pw.TableRow(children: colHdrCells, repeat: true),
    ];

    var rowNumber = 0;
    for (final colorId in chunkRowKeys) {
      rowNumber++;
      final meta  = rowMeta[colorId]!;
      final rowBg = rowNumber.isOdd ? _grayRow : PdfColors.white;
      double rowSqm = 0;

      final cells = <pw.Widget>[
        _tc(text: '$rowNumber', height: _kRowH, bg: rowBg, fontSize: _fsTd),
        _tc(
          text:     '${meta.productName}  |  ${meta.colorName?.toUpperCase() ?? "—"}\n'
                    '${meta.qualityName ?? "—"} / ${meta.productTypeName ?? "—"}',
          height:   _kRowH,
          bg:       rowBg,
          fontSize: _fsTd - 0.5,
          align:    pw.TextAlign.left,
        ),
      ];

      for (var j = 0; j < chunk.length; j++) {
        final sizeId = chunk[j];
        final item   = cellMap[(colorId, sizeId)];
        final tId    = typeByJ[j] ?? 0;
        final typeBg = _typePalette[typeColorMap[tId] ?? 0];
        final thick  = firstByT[tId] == j;
        if (item != null) {
          if (item.sizeLength != null && item.sizeWidth != null) {
            rowSqm += item.sizeLength! * item.sizeWidth! * item.quantity / 10000.0;
          }
          cells.add(_tc(text: '${item.quantity}', height: _kRowH, bg: typeBg, bold: true, fontSize: _fsTd, thickLeft: thick));
        } else {
          cells.add(_tc(text: '—', height: _kRowH, bg: _disabledBg, fg: _textSec, fontSize: _fsTd, thickLeft: thick));
        }
      }
      cells.add(_tc(
        text:     rowSqm > 0 ? rowSqm.toStringAsFixed(2) : '—',
        height:   _kRowH,
        bg:       rowBg,
        bold:     true,
        fontSize: _fsTd,
      ));
      tableRows.add(pw.TableRow(children: cells));
    }

    return pw.Table(
      columnWidths: colWidths,
      tableWidth:   pw.TableWidth.min,
      children:     tableRows,
    );
  }

  // ─── Generic totals row ───────────────────────────────────────────────────
  pw.Widget _totalsRow({
    required List<int> rowKeys,
    required List<int> chunk,
    required Map<(int, int), OrderItemEntity> cellMap,
    required Map<int, OrderItemEntity> sizeMeta,
    required Map<int, List<int>> chunkTypeGroups,
    required Map<int, int> typeColorMap,
    required String label,
    required String Function(int sizeId, List<int> colorIds) valueFn,
    required String Function(List<int> colorIds, List<int> chunkSizes) totalFn,
    required bool topThick,
  }) {
    final typeByJ  = <int, int>{};
    final firstByT = <int, int>{};
    for (final e in chunkTypeGroups.entries) {
      for (final j in e.value) typeByJ[j] = e.key;
      if (e.value.isNotEmpty) firstByT[e.key] = e.value.first;
    }

    final sizeCells = List.generate(chunk.length, (j) {
      final sizeId = chunk[j];
      final typeId = typeByJ[j] ?? 0;
      final typeBg = _typePalette[typeColorMap[typeId] ?? 0];
      final thick  = firstByT[typeId] == j;
      return _cell(
        text:      valueFn(sizeId, rowKeys),
        width:     _kColSize,
        height:    _kRowH,
        bg:        typeBg,
        fg:        _primary,
        bold:      true,
        fontSize:  _fsTd,
        thickLeft: thick,
        topThick:  topThick,
      );
    });

    return pw.Row(children: [
      _cell(text: '',    width: _kColNum,  height: _kRowH, bg: _successBg, topThick: topThick),
      _cell(text: label, width: _kColMeta, height: _kRowH, bg: _successBg, fg: _primary, bold: true, fontSize: _fsTd, align: pw.TextAlign.left, topThick: topThick),
      ...sizeCells,
      _cell(text: totalFn(rowKeys, chunk), width: _kColTot, height: _kRowH, bg: _successBg, fg: _primary, bold: true, fontSize: _fsTd, topThick: topThick),
    ]);
  }

  // ─── Cell widget ──────────────────────────────────────────────────────────
  pw.Widget _cell({
    required String text,
    required double width,
    required double height,
    PdfColor? bg,
    PdfColor? fg,
    bool bold          = false,
    double fontSize    = 7.5,
    pw.TextAlign align = pw.TextAlign.center,
    bool thickLeft     = false,
    bool topThick      = false,
  }) {
    final containerAlign = align == pw.TextAlign.left
        ? pw.Alignment.centerLeft
        : pw.Alignment.center;

    return pw.Container(
      width:  width,
      height: height,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border(
          left:   pw.BorderSide(color: thickLeft ? _primary : _borderColor, width: thickLeft ? 1.2 : 0.4),
          right:  pw.BorderSide(color: _borderColor, width: 0.4),
          top:    pw.BorderSide(color: topThick  ? _primary : _borderColor, width: topThick  ? 1.2 : 0.4),
          bottom: pw.BorderSide(color: _borderColor, width: 0.4),
        ),
      ),
      alignment: containerAlign,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize:   fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color:      fg ?? PdfColors.black,
        ),
        textAlign: align,
        maxLines:  2,
        overflow:  pw.TextOverflow.clip,
      ),
    );
  }

  // ─── Table cell (no fixed width — column width managed by pw.Table) ───────────
  pw.Widget _tc({
    required String text,
    required double height,
    PdfColor? bg,
    PdfColor? fg,
    bool bold          = false,
    double fontSize    = 7.5,
    pw.TextAlign align = pw.TextAlign.center,
    bool thickLeft     = false,
    bool topThick      = false,
  }) {
    final containerAlign = align == pw.TextAlign.left
        ? pw.Alignment.centerLeft
        : pw.Alignment.center;
    return pw.Container(
      height: height,
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border(
          left:   pw.BorderSide(color: thickLeft ? _primary : _borderColor, width: thickLeft ? 1.2 : 0.4),
          right:  pw.BorderSide(color: _borderColor, width: 0.4),
          top:    pw.BorderSide(color: topThick  ? _primary : _borderColor, width: topThick  ? 1.2 : 0.4),
          bottom: pw.BorderSide(color: _borderColor, width: 0.4),
        ),
      ),
      alignment: containerAlign,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize:   fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color:      fg ?? PdfColors.black,
        ),
        textAlign: align,
        maxLines:  2,
        overflow:  pw.TextOverflow.clip,
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _statusLabel(String s) => switch (s) {
        'pending'       => 'Kutilmoqda',
        'planned'       => 'Rejalashtirilgan',
        'on_production' => 'Ishlab chiqarilmoqda',
        'done'          => 'Bajarildi',
        'canceled'      => 'Bekor qilindi',
        _               => s,
      };

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
