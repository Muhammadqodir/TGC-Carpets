import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../datasources/warehouse_remote_datasource.dart';
import '../../presentation/pages/warehouse_document_preview_args.dart';

class WarehousePdfService {
  final WarehouseRemoteDataSource _dataSource;

  const WarehousePdfService(this._dataSource);

  /// Generates a PDF for the given document and uploads it to the server.
  /// Silently ignores upload failures so the caller is not blocked.
  Future<void> generateAndUpload({
    required int docId,
    required String username,
    required DateTime documentDate,
    required String? notes,
    required List<WarehouseItemPreviewRow> items,
  }) async {
    final bytes = await _buildPdf(
      docId: docId,
      username: username,
      documentDate: documentDate,
      notes: notes,
      items: items,
    );
    await _dataSource.uploadPdfBytes(docId, bytes);
  }

  Future<Uint8List> _buildPdf({
    required int docId,
    required String username,
    required DateTime documentDate,
    required String? notes,
    required List<WarehouseItemPreviewRow> items,
  }) async {
    final regularData = await rootBundle.load('fonts/Onest-Regular.ttf');
    final boldData = await rootBundle.load('fonts/Onest-Bold.ttf');
    final font = pw.Font.ttf(regularData.buffer.asByteData());
    final boldFont = pw.Font.ttf(boldData.buffer.asByteData());

    final baseStyle = pw.TextStyle(font: font, fontSize: 11);
    final boldStyle = pw.TextStyle(
        font: boldFont, fontSize: 11, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(
        font: boldFont, fontSize: 16, fontWeight: pw.FontWeight.bold);
    final subtitleStyle = pw.TextStyle(
        font: boldFont, fontSize: 13, fontWeight: pw.FontWeight.bold);

    final totalQty = items.fold<int>(0, (s, r) => s + r.quantity);
    final sqmList =
        items.map((r) => r.squareMeters).whereType<double>().toList();
    final totalSqm =
        sqmList.isEmpty ? null : sqmList.fold<double>(0.0, (a, b) => a + b);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────
            pw.Center(
              child: pw.Text('TGC CARPETS', style: titleStyle),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('OMBORGA KIRIM HUJJATI', style: subtitleStyle),
            ),
            pw.Center(
              child: pw.Text('\u2116 $docId', style: subtitleStyle),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1.5, color: PdfColors.black),
            pw.SizedBox(height: 8),

            // ── Meta ─────────────────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Masul xodim: $username', style: baseStyle),
                pw.Text('Sana: ${_fmt(documentDate)}', style: baseStyle),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Izoh: $notes', style: baseStyle),
            ],
            pw.SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
              columnWidths: {
                0: const pw.FixedColumnWidth(22),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FixedColumnWidth(70),
                6: const pw.FixedColumnWidth(50),
                7: const pw.FixedColumnWidth(75),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('#', boldStyle),
                    _cell('Mahsulot', boldStyle),
                    _cell('Sifat', boldStyle),
                    _cell('Turi', boldStyle),
                    _cell('Rangi', boldStyle),
                    _cell("O'lcham", boldStyle),
                    _cell('Miqdor', boldStyle),
                    _cell('Miqdor(м²)', boldStyle),
                  ],
                ),
                // Data rows
                ...items.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  final bg = i.isOdd ? PdfColors.grey100 : PdfColors.white;
                  final small = pw.TextStyle(font: font, fontSize: 9);
                  final smallBold = pw.TextStyle(
                      font: font, fontSize: 9, fontWeight: pw.FontWeight.bold);
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _cell('${i + 1}', small),
                      _cell(item.productName, small),
                      _cell(item.quality ?? '—', small),
                      _cell(item.type ?? '—', small),
                      _cell(item.color ?? '—', small),
                      _cell(item.sizeLabel ?? '—', small),
                      _cell('${item.quantity}', smallBold),
                      _cell(
                          item.squareMeters != null
                              ? fmtSqM(item.squareMeters!)
                              : '—',
                          smallBold),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Jami: $totalQty dona', style: boldStyle),
                    if (totalSqm != null)
                      pw.Text('Jami: ${fmtSqM(totalSqm)}', style: boldStyle),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _cell(String text, pw.TextStyle style) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: style),
      );

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
