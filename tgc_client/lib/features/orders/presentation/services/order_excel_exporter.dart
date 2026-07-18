import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:tgc_client/features/orders/domain/entities/order_entity.dart';

/// Builds an Excel workbook for an order, mirroring the shipment xlsx layout
/// (see ShipmentService::generateAndStoreXlsx on the backend): a single flat
/// sheet with one row per order item, a blue header band, and thin borders.
class OrderExcelExporter {
  static final _headerFill = ExcelColor.fromHexString('FF2E5BA8');
  static final _white = ExcelColor.fromHexString('FFFFFFFF');
  static final _headerBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('FFCCCCCC'),
  );
  static final _dataBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('FFDDDDDD'),
  );

  Uint8List export(OrderEntity order) {
    final excel = Excel.createExcel();

    const sheetName = 'Buyurtma ro\'yxati';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    // ── Header row ──────────────────────────────────────────────────────────
    const headers = [
      'Buyurtma',
      'Sana',
      'Toliq nomi',
      'Barcode',
      'Buyurtma (soni)',
      'Buyurtma (m2)',
      'Sifat',
      'Model',
      'Rang',
      "O'lcham",
      'Kengligi',
      'Uzunligi',
    ];

    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: _white,
      backgroundColorHex: _headerFill,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: _headerBorder,
      rightBorder: _headerBorder,
      topBorder: _headerBorder,
      bottomBorder: _headerBorder,
    );

    for (var c = 0; c < headers.length; c++) {
      _writeCell(sheet, 0, c, TextCellValue(headers[c]), headerStyle);
    }
    sheet.setRowHeight(0, 22);

    // ── Data rows ───────────────────────────────────────────────────────────
    final orderDate = _formatDate(order.orderDate);

    final dataStyle = CellStyle(
      verticalAlign: VerticalAlign.Center,
      leftBorder: _dataBorder,
      rightBorder: _dataBorder,
      topBorder: _dataBorder,
      bottomBorder: _dataBorder,
    );

    var row = 1;
    for (final item in order.items) {
      final width = item.sizeWidth ?? 0;
      final length = item.sizeLength ?? 0;
      final qty = item.quantity;
      final sqm = (width * length * qty) / 10000.0;

      final sizeLabel = (width != 0 && length != 0) ? '${width}x$length' : '';
      final qualityName = item.qualityName ?? '';
      final productName = item.productName;
      final colorName = item.colorName ?? '';
      final edgeCode = item.edgeCode ?? '';
      final fullName =
          '$qualityName $productName $colorName $sizeLabel $edgeCode'.trim();

      _writeCell(sheet, row, 0, IntCellValue(order.id), dataStyle);
      _writeCell(sheet, row, 1, TextCellValue(orderDate), dataStyle);
      _writeCell(sheet, row, 2, TextCellValue(fullName), dataStyle);
      _writeCell(
          sheet, row, 3, TextCellValue(item.variantBarcode ?? ''), dataStyle);
      _writeCell(sheet, row, 4, IntCellValue(qty), dataStyle);
      _writeCell(
        sheet,
        row,
        5,
        DoubleCellValue(double.parse(sqm.toStringAsFixed(4))),
        dataStyle,
      );
      _writeCell(sheet, row, 6, TextCellValue(qualityName), dataStyle);
      _writeCell(sheet, row, 7, TextCellValue(productName), dataStyle);
      _writeCell(sheet, row, 8, TextCellValue(colorName), dataStyle);
      _writeCell(sheet, row, 9, TextCellValue(sizeLabel), dataStyle);
      _writeCell(sheet, row, 10, IntCellValue(width), dataStyle);
      _writeCell(sheet, row, 11, IntCellValue(length), dataStyle);

      row++;
    }

    // ── Column widths ───────────────────────────────────────────────────────
    const widths = [14, 12, 40, 18, 14, 14, 14, 20, 14, 10, 10, 10];
    for (var c = 0; c < widths.length; c++) {
      sheet.setColumnWidth(c, widths[c].toDouble());
    }

    final bytes = excel.encode()!;
    return Uint8List.fromList(bytes);
  }

  void _writeCell(
      Sheet sheet, int row, int col, CellValue value, CellStyle style) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = value;
    cell.cellStyle = style;
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
