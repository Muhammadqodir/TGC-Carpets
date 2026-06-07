import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:tgc_client/features/orders/domain/entities/order_entity.dart';
import 'package:tgc_client/features/orders/domain/entities/order_item_entity.dart';

/// Builds an Excel workbook that mirrors the order_items_sheet matrix layout.
///
/// Sheet layout:
///   - Header block : order metadata (client, date, totals, notes)
///   - Type label row: product-type names spanning their size columns
///   - Column header row: #, Mahsulot, Rang, Sifat/Tur, <size…>, Jami m²
///   - Data rows: one per unique (productColorId) combination
///   - Footer row: per-column totals
class OrderExcelExporter {
  // ── Brand colours (matching AppColors) ─────────────────────────────────────
  static final _primary = ExcelColor.fromHexString('FF1565C0');
  static final _primaryLight = ExcelColor.fromHexString('FFE3F2FD');
  static final _white = ExcelColor.fromHexString('FFFFFFFF');
  static final _gray = ExcelColor.fromHexString('FFF5F5F5');
  static final _textSecondary = ExcelColor.fromHexString('FF757575');
  static final _successBg = ExcelColor.fromHexString('FFE8F5E9');

  static final _typePalette = <ExcelColor>[
    ExcelColor.fromHexString('FFBBDEFB'), // blue-100
    ExcelColor.fromHexString('FFC8E6C9'), // green-100
    ExcelColor.fromHexString('FFFFE0B2'), // orange-100
    ExcelColor.fromHexString('FFE1BEE7'), // purple-100
    ExcelColor.fromHexString('FFB2DFDB'), // teal-100
    ExcelColor.fromHexString('FFF8BBD0'), // pink-100
  ];

  static final _typeDividerBorder = Border(
    borderStyle: BorderStyle.Medium,
    borderColorHex: ExcelColor.fromHexString('FF9E9E9E'),
  );

  static final _thinBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('FF000000'),
  );

  Uint8List export(OrderEntity order) {
    final excel = Excel.createExcel();

    // Rename the default sheet; delete the placeholder if another exists.
    final sheetName = 'Buyurtma #${order.id}';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // ── Pre-compute matrix structure ─────────────────────────────────────────
    // Rows: unique productColorId (preserving insertion order from items list)
    final rowKeys = <int>[];
    final seenColors = <int>{};
    for (final item in order.items) {
      if (seenColors.add(item.productColorId)) {
        rowKeys.add(item.productColorId);
      }
    }

    // Columns: unique productSizeId (preserving order), null-size items ignored
    final sizeIds = <int>[];
    final seenSizes = <int>{};
    for (final item in order.items) {
      if (item.productSizeId != null && seenSizes.add(item.productSizeId!)) {
        sizeIds.add(item.productSizeId!);
      }
    }

    // Fast lookup: (productColorId, productSizeId) → item
    final cellMap = <(int, int), OrderItemEntity>{};
    for (final item in order.items) {
      if (item.productSizeId != null) {
        cellMap[(item.productColorId, item.productSizeId!)] = item;
      }
    }

    // Representative item per productColorId (for product/color meta)
    final rowMeta = <int, OrderItemEntity>{};
    for (final item in order.items) {
      rowMeta.putIfAbsent(item.productColorId, () => item);
    }

    // Size metadata indexed by sizeId
    final sizeMeta = <int, OrderItemEntity>{};
    for (final item in order.items) {
      if (item.productSizeId != null) {
        sizeMeta.putIfAbsent(item.productSizeId!, () => item);
      }
    }

    // ── Column index layout ──────────────────────────────────────────────────
    // 0: #  |  1: Mahsulot  |  2: Rang  |  3: Sifat / Tur
    // 4..4+S-1: size columns
    // 4+S: Jami m²
    const kMetaCols = 2;
    final totalCols = kMetaCols + sizeIds.length + 1; // +1 for Jami m²
    final sqmColIdx = kMetaCols + sizeIds.length;

    // ── Column widths ────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 10); // #
    sheet.setColumnWidth(1, 32); // Mahsulot / Rang + Sifat / Tur
    for (var i = 0; i < sizeIds.length; i++) {
      sheet.setColumnWidth(kMetaCols + i, 12);
    }
    sheet.setColumnWidth(sqmColIdx, 12); // Jami m²

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 1 — Header block
    // ─────────────────────────────────────────────────────────────────────────
    int row = 0;

    // Title row
    _writeCell(
      sheet,
      row,
      0,
      TextCellValue('BUYURTMA #${order.id}  •  TGC CARPETS'),
      CellStyle(
        bold: true,
        fontSize: 14,
        backgroundColorHex: _primary,
        fontColorHex: _white,
        horizontalAlign: HorizontalAlign.Left,
        verticalAlign: VerticalAlign.Center,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
      ),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: row),
    );
    sheet.setRowHeight(row, 30);
    row++;

    // Metadata rows: one label-value pair per row, no merging
    final metaItems = [
      ('Mijoz', '${order.clientShopName ?? '—'} / ${order.clientRegion ?? '—'}'),
      ('Sana', _formatDate(order.orderDate)),
    ];

    for (final (k, v) in metaItems) {
      _writeInfoRow(sheet, row, totalCols, k, v);
      sheet.setRowHeight(row, 20);
      row++;
    }

    if (order.notes != null && order.notes!.isNotEmpty) {
      _writeCell(
        sheet,
        row,
        0,
        TextCellValue('Izoh: ${order.notes!}'),
        CellStyle(
          italic: true,
          fontSize: 10,
          fontColorHex: _textSecondary,
          backgroundColorHex: _gray,
          textWrapping: TextWrapping.WrapText,
          leftBorder: _thinBorder,
          rightBorder: _thinBorder,
          topBorder: _thinBorder,
          bottomBorder: _thinBorder,
        ),
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: totalCols - 1, rowIndex: row),
      );
      sheet.setRowHeight(row, 20);
      row++;
    }

    // Blank spacer — write empty bordered cells across all columns
    for (var c = 0; c < totalCols; c++) {
      _writeCell(
        sheet,
        row,
        c,
        TextCellValue(''),
        CellStyle(
          leftBorder: _thinBorder,
          rightBorder: _thinBorder,
          topBorder: _thinBorder,
          bottomBorder: _thinBorder,
        ),
      );
    }
    row++;

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 2 — Product-type label row (spans size columns per type)
    // ─────────────────────────────────────────────────────────────────────────

    // Build typeId → list of (colIndex, sizeId) mapping
    final typeGroups = <int, List<int>>{}; // typeId → column indices
    for (var i = 0; i < sizeIds.length; i++) {
      final meta = sizeMeta[sizeIds[i]];
      final typeId = meta?.productTypeId ?? 0;
      (typeGroups[typeId] ??= []).add(kMetaCols + i);
    }

    // typeId → palette colour index (first-seen order)
    final typeColorMap = <int, int>{};
    var typeColorIdx = 0;
    for (final typeId in typeGroups.keys) {
      typeColorMap[typeId] = typeColorIdx++ % _typePalette.length;
    }

    // Build typeId → typeName
    final typeNames = <int, String>{};
    for (final item in order.items) {
      if (item.productTypeId != null) {
        typeNames[item.productTypeId!] = item.productTypeName ?? 'Tur';
      }
    }

    // Empty cells for meta columns in type-label row
    for (var c = 0; c < kMetaCols; c++) {
      _writeCell(
        sheet,
        row,
        c,
        TextCellValue(''),
        CellStyle(
          backgroundColorHex: _primaryLight,
          leftBorder: _thinBorder,
          rightBorder: _thinBorder,
          topBorder: _thinBorder,
          bottomBorder: _thinBorder,
        ),
      );
    }
    // Type label cells — each type gets its palette colour and a divider on the left
    for (final entry in typeGroups.entries) {
      final cols = entry.value;
      final name = typeNames[entry.key] ?? 'Tur #${entry.key}';
      final tci = typeColorMap[entry.key] ?? 0;
      _writeCell(
        sheet,
        row,
        cols.first,
        TextCellValue(name),
        CellStyle(
          bold: true,
          fontSize: 9,
          backgroundColorHex: _typePalette[tci],
          fontColorHex: _primary,
          horizontalAlign: HorizontalAlign.Center,
          leftBorder: _typeDividerBorder,
          rightBorder: _thinBorder,
          topBorder: _thinBorder,
          bottomBorder: _thinBorder,
        ),
      );
      if (cols.length > 1) {
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: cols.first, rowIndex: row),
          CellIndex.indexByColumnRow(columnIndex: cols.last, rowIndex: row),
        );
      }
    }
    // Jami m² label cell
    _writeCell(
      sheet,
      row,
      sqmColIdx,
      TextCellValue(''),
      CellStyle(
        backgroundColorHex: _primaryLight,
        leftBorder: _thinBorder,
        rightBorder: _thinBorder,
        topBorder: _thinBorder,
        bottomBorder: _thinBorder,
      ),
    );
    sheet.setRowHeight(row, 18);
    row++;

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 3 — Column header row
    // ─────────────────────────────────────────────────────────────────────────

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: _primary,
      fontColorHex: _white,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );

    _writeCell(sheet, row, 0, TextCellValue('#'), headerStyle);
    _writeCell(
      sheet,
      row,
      1,
      TextCellValue('Mahsulot  |  Rang\nSifat / Tur'),
      headerStyle.copyWith(textWrappingVal: TextWrapping.WrapText),
    );
    for (var i = 0; i < sizeIds.length; i++) {
      final m = sizeMeta[sizeIds[i]];
      final label = (m?.sizeWidth != null && m?.sizeLength != null)
          ? '${m!.sizeWidth}×${m.sizeLength}'
          : 'O\'lcham ${i + 1}';
      final typeId = m?.productTypeId ?? 0;
      final tci = typeColorMap[typeId] ?? 0;
      final isFirstInGroup = typeGroups[typeId]?.first == kMetaCols + i;
      _writeCell(
        sheet,
        row,
        kMetaCols + i,
        TextCellValue(label),
        headerStyle.copyWith(
          backgroundColorHexVal: _typePalette[tci],
          fontColorHexVal: _primary,
          leftBorderVal: isFirstInGroup ? _typeDividerBorder : _thinBorder,
        ),
      );
    }
    _writeCell(sheet, row, sqmColIdx, TextCellValue('Jami m²'), headerStyle);
    sheet.setRowHeight(row, 22);
    row++;

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 4 — Data rows
    // ─────────────────────────────────────────────────────────────────────────

    final dataStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    final dataStyleLeft = dataStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Left,
    );

    // Save the first data row index for formula references.
    final dataRowStart = row;

    for (var ri = 0; ri < rowKeys.length; ri++) {
      final colorId = rowKeys[ri];
      final meta = rowMeta[colorId]!;

      // # column — no bg
      _writeCell(sheet, row, 0, IntCellValue(ri + 1), dataStyle);

      // Mahsulot | Rang (line 1) / Sifat / Tur (line 2) — no bg
      _writeCell(
        sheet,
        row,
        1,
        TextCellValue(
          '${meta.productName}${meta.edgeCode != null ? ' [${meta.edgeCode}]' : ''}  |  ${meta.colorName?.toUpperCase() ?? '—'}\n'
          '${meta.qualityName ?? '—'} / ${meta.productTypeName ?? '—'}',
        ),
        dataStyleLeft.copyWith(textWrappingVal: TextWrapping.WrapText),
      );

      // Size quantity cells — type-coloured bg + divider on first column of each type
      double rowSqm = 0;
      for (var ci = 0; ci < sizeIds.length; ci++) {
        final sizeId = sizeIds[ci];
        final item = cellMap[(colorId, sizeId)];
        final typeId = sizeMeta[sizeId]?.productTypeId ?? 0;
        final tci = typeColorMap[typeId] ?? 0;
        final typeBg = _typePalette[tci];
        final isFirstInGroup = typeGroups[typeId]?.first == kMetaCols + ci;
        final leftBorder = isFirstInGroup ? _typeDividerBorder : _thinBorder;
        if (item != null) {
          final sqmUnit = (item.sizeLength != null && item.sizeWidth != null)
              ? item.sizeLength! * item.sizeWidth! / 10000.0
              : 0.0;
          rowSqm += sqmUnit * item.quantity;
          _writeCell(
            sheet,
            row,
            kMetaCols + ci,
            IntCellValue(item.quantity),
            dataStyle.copyWith(
              boldVal: true,
              backgroundColorHexVal: typeBg,
              leftBorderVal: leftBorder,
            ),
          );
        } else {
          // Disabled cell (incompatible type)
          _writeCell(
            sheet,
            row,
            kMetaCols + ci,
            TextCellValue('—'),
            dataStyle.copyWith(
              fontColorHexVal: _textSecondary,
              backgroundColorHexVal: ExcelColor.fromHexString('FFEEEEEE'),
              leftBorderVal: leftBorder,
            ),
          );
        }
      }

      // Jami m² — no bg
      _writeCell(
        sheet,
        row,
        sqmColIdx,
        DoubleCellValue(double.parse(rowSqm.toStringAsFixed(2))),
        dataStyle.copyWith(
          boldVal: true,
          numberFormat: NumFormat.standard_2,
        ),
      );

      sheet.setRowHeight(row, 32);
      row++;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SECTION 5 — Footer (totals) row
    // ─────────────────────────────────────────────────────────────────────────

    final footerStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: _successBg,
      fontColorHex: _primary,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder:
          Border(borderStyle: BorderStyle.Medium, borderColorHex: _primary),
      bottomBorder: _thinBorder,
    );

    _writeCell(sheet, row, 0, TextCellValue(''), footerStyle);
    _writeCell(
      sheet,
      row,
      1,
      TextCellValue('JAMI (dona)'),
      footerStyle.copyWith(horizontalAlignVal: HorizontalAlign.Left),
    );

    for (var ci = 0; ci < sizeIds.length; ci++) {
      final sizeId = sizeIds[ci];
      final typeId = sizeMeta[sizeId]?.productTypeId ?? 0;
      final isFirstInGroup = typeGroups[typeId]?.first == kMetaCols + ci;
      final colLetter = _colLetter(kMetaCols + ci);
      _writeCell(
        sheet,
        row,
        kMetaCols + ci,
        FormulaCellValue(
          'SUM($colLetter${dataRowStart + 1}:$colLetter${dataRowStart + rowKeys.length})'),
        footerStyle.copyWith(
          leftBorderVal: isFirstInGroup ? _typeDividerBorder : _thinBorder,
        ),
      );
    }

    _writeCell(
      sheet,
      row,
      sqmColIdx,
      FormulaCellValue(
        'SUM(${_colLetter(sqmColIdx)}${dataRowStart + 1}:${_colLetter(sqmColIdx)}${dataRowStart + rowKeys.length})'),
      footerStyle.copyWith(numberFormat: NumFormat.standard_2),
    );
    sheet.setRowHeight(row, 22);
    row++;

    // ── Sqm totals row ──────────────────────────────────────────────────────
    final sqmFooterStyle = footerStyle.copyWith(topBorderVal: _thinBorder);

    _writeCell(sheet, row, 0, TextCellValue(''), sqmFooterStyle);
    _writeCell(
      sheet,
      row,
      1,
      TextCellValue('Jami m²'),
      sqmFooterStyle.copyWith(horizontalAlignVal: HorizontalAlign.Left),
    );

    for (var ci = 0; ci < sizeIds.length; ci++) {
      final sizeId = sizeIds[ci];
      final m = sizeMeta[sizeId];
      final typeId = m?.productTypeId ?? 0;
      final isFirstInGroup = typeGroups[typeId]?.first == kMetaCols + ci;
      final colLetter = _colLetter(kMetaCols + ci);
      final CellValue sqmCellValue;
      if (m?.sizeLength != null && m?.sizeWidth != null) {
        sqmCellValue = FormulaCellValue(
          'SUM($colLetter${dataRowStart + 1}:$colLetter${dataRowStart + rowKeys.length})*${m!.sizeWidth}*${m.sizeLength}/10000',
        );
      } else {
        sqmCellValue = TextCellValue('—');
      }
      _writeCell(
        sheet,
        row,
        kMetaCols + ci,
        sqmCellValue,
        sqmFooterStyle.copyWith(
          leftBorderVal: isFirstInGroup ? _typeDividerBorder : _thinBorder,
          numberFormat: NumFormat.standard_2,
        ),
      );
    }

    _writeCell(
      sheet,
      row,
      sqmColIdx,
      FormulaCellValue(
        'SUM(${_colLetter(sqmColIdx)}${dataRowStart + 1}:${_colLetter(sqmColIdx)}${dataRowStart + rowKeys.length})'),
      sqmFooterStyle.copyWith(numberFormat: NumFormat.standard_2),
    );
    sheet.setRowHeight(row, 22);

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _writeCell(
      Sheet sheet, int row, int col, CellValue value, CellStyle style) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    cell.cellStyle = style;
  }

  /// Writes a metadata row: label in col A (0), value in col B (1),
  /// remaining columns filled with empty bordered cells. No merging.
  void _writeInfoRow(
    Sheet sheet,
    int row,
    int totalCols,
    String label,
    String value,
  ) {
    final labelStyle = CellStyle(
      bold: true,
      fontSize: 12,
      backgroundColorHex: _primaryLight,
      fontColorHex: _primary,
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    final valueStyle = CellStyle(
      fontSize: 12,
      backgroundColorHex: _white,
      horizontalAlign: HorizontalAlign.Left,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    final emptyStyle = CellStyle(
      backgroundColorHex: _white,
      leftBorder: _thinBorder,
      rightBorder: _thinBorder,
      topBorder: _thinBorder,
      bottomBorder: _thinBorder,
    );
    _writeCell(sheet, row, 0, TextCellValue('$label:'), labelStyle);
    _writeCell(sheet, row, 1, TextCellValue(value), valueStyle);
    for (var c = 2; c < totalCols; c++) {
      _writeCell(sheet, row, c, TextCellValue(''), emptyStyle);
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  /// Converts a 0-based column index to an Excel column letter (A, B, …, Z, AA, …).
  String _colLetter(int col) {
    if (col < 26) return String.fromCharCode(65 + col);
    return '${String.fromCharCode(65 + (col ~/ 26) - 1)}${String.fromCharCode(65 + col % 26)}';
  }
}
