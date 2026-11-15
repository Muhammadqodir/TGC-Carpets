import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/production_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';
import '../../domain/production_shift_breakdown.dart';

/// The production analytics page as a printable A4 report for the period
/// the page shows: shifts, machines, shift × quality and Kovrolin shift ×
/// roll width.
class ProductionReportPdfExporter {
  static final _primary = PdfColor.fromHex('010852');
  static final _headerBg = PdfColor.fromHex('E8EAF6');
  static final _subtotalBg = PdfColor.fromHex('F5F5F5');
  static final _border = PdfColor.fromHex('BDBDBD');
  static final _muted = PdfColor.fromHex('6B6B6B');

  /// The page's font, so o‘, m² and № print. Tests pass a theme of their
  /// own to skip the asset bundle.
  final Future<pw.ThemeData> Function() _theme;

  ProductionReportPdfExporter({Future<pw.ThemeData> Function()? theme}) : _theme = theme ?? _onest;

  static Future<pw.ThemeData> _onest() async => pw.ThemeData.withFont(
        base: pw.Font.ttf(await rootBundle.load('fonts/Onest-Regular.ttf')),
        bold: pw.Font.ttf(await rootBundle.load('fonts/Onest-Bold.ttf')),
      );

  static String fileName(ProductionAnalyticsEntity data) =>
      'Ishlab_chiqarish_${data.periodFrom}_${data.periodTo}.pdf';

  Future<Uint8List> export(ProductionAnalyticsEntity data, {DateTime? generatedAt}) async {
    final ops = data.operations;
    final doc = pw.Document(title: 'Ishlab chiqarish hisoboti', author: 'TGC Carpets');
    final now = generatedAt ?? DateTime.now();

    doc.addPage(
      pw.MultiPage(
        theme: await _theme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _runningHeader(data),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _muted)),
        ),
        build: (ctx) => [
          pw.Text('Ishlab chiqarish hisoboti',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primary)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Davr: ${_date(data.periodFrom)} — ${_date(data.periodTo)}   ·   '
            'Tuzildi: ${_date(now.toIso8601String().substring(0, 10))} '
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
          if (ops != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Yorliq chop etilgan vaqt bo‘yicha. Ish kuni '
              '${ops.dayStartHour.toString().padLeft(2, '0')}:00 da boshlanadi.'
              '${ops.backfilledExcluded > 0 ? ' Iyul 2026 dan oldingi ${ops.backfilledExcluded} dona hisobga olinmagan.' : ''}',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
          pw.SizedBox(height: 12),
          _summary(data),
          if (ops == null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text('Smena va stanok ma’lumotlari yo‘q.', style: const pw.TextStyle(fontSize: 9)),
            )
          else ...[
            _title('Smenalar bo‘yicha'),
            _capacityTable('Smena', ops.byShift),
            _title('Smenalar — sifat bo‘yicha'),
            _breakdownTable('Sifat', 'Dona', shiftQualityGroups(ops), 'Bu davrda chop etilgan yorliq yo‘q.'),
            _title('Kovrolin — smenalar, rulon eni bo‘yicha'),
            _breakdownTable('Eni', 'Rulon', shiftWidthGroups(ops), 'Bu davrda Kovrolin ishlab chiqarilmagan.'),
            _title('Stanoklar bo‘yicha'),
            _capacityTable('Stanok', ops.byMachine),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ─── Pieces ──────────────────────────────────────────────────────────────

  pw.Widget _runningHeader(ProductionAnalyticsEntity data) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          'Ishlab chiqarish hisoboti · ${_date(data.periodFrom)} — ${_date(data.periodTo)}',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      );

  pw.Widget _title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _primary)),
      );

  pw.Widget _summary(ProductionAnalyticsEntity data) {
    final ops = data.operations;
    final cells = <(String, String)>[
      ('Partiyalar', formatQty(data.summary.totalBatches)),
      ('Ishlab chiqarildi', '${formatQty(data.summary.totalProduced)} dona'),
      ('Maydon', '${formatSqm(data.summary.totalSqm)} m²'),
      if (ops != null) ...[
        ('Ish kunlari', formatQty(ops.summary.workingDays)),
        ('Brak', '${formatQty(ops.summary.totalDefects)} dona'),
      ],
    ];

    return pw.Row(
      children: [
        for (final (label, value) in cells)
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(right: 6),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _border, width: 0.5),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(label, style: pw.TextStyle(fontSize: 7, color: _muted)),
                  pw.SizedBox(height: 2),
                  pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _capacityTable(String nameHeader, List<ProductionCapacityStats> rows) {
    if (rows.isEmpty) return _empty('Ma’lumot yo‘q.');

    String pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(0)}%';
    String best(int qty, String? date) => date == null ? '—' : '$qty (${_date(date)})';

    return _table(
      headers: [nameHeader, 'Dona', 'm²', 'Ish kuni', 'O‘rt./kun', 'Eng yaxshi kun', 'Quvvat', 'Brak', 'Qayta chop'],
      flex: [30, 9, 11, 7, 9, 16, 8, 7, 8],
      rows: [
        for (final r in rows)
          _Row([
            r.name,
            formatQty(r.totalQuantity),
            formatSqm(r.totalSqm),
            formatQty(r.workingDays),
            r.avgQuantityPerDay.toStringAsFixed(1),
            best(r.bestDayQuantity, r.bestDayQuantityDate),
            pct(r.utilizationQuantity),
            formatQty(r.totalDefects),
            formatQty(r.extraPrints),
          ]),
      ],
    );
  }

  pw.Widget _breakdownTable(String lineHeader, String countHeader, List<ShiftBreakdownGroup> groups, String empty) {
    if (groups.isEmpty) return _empty(empty);

    final rows = <_Row>[];
    for (final g in groups) {
      for (final (i, l) in g.lines.indexed) {
        rows.add(_Row([i == 0 ? g.shiftName : '', l.label, formatQty(l.quantity), formatSqm(l.sqm)]));
      }
      if (g.lines.length > 1) {
        rows.add(_Row(['', 'Jami', formatQty(g.totalQuantity), formatSqm(g.totalSqm)], subtotal: true));
      }
    }
    rows.add(_Row([
      'Hammasi',
      '',
      formatQty(groups.fold<int>(0, (s, g) => s + g.totalQuantity)),
      formatSqm(groups.fold<double>(0, (s, g) => s + g.totalSqm)),
    ], subtotal: true));

    return _table(
      headers: ['Smena', lineHeader, countHeader, 'm²'],
      flex: [35, 35, 15, 15],
      rows: rows,
    );
  }

  pw.Widget _table({required List<String> headers, required List<int> flex, required List<_Row> rows}) {
    pw.Widget cell(String text, int col, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(
            text,
            textAlign: col == 0 || (col == 1 && headers.length == 4) ? pw.TextAlign.left : pw.TextAlign.right,
            style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        );

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _border, width: 0.4),
        bottom: pw.BorderSide(color: _border, width: 0.4),
        top: pw.BorderSide(color: _border, width: 0.4),
      ),
      columnWidths: {for (final (i, f) in flex.indexed) i: pw.FlexColumnWidth(f.toDouble())},
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _headerBg),
          children: [for (final (i, h) in headers.indexed) cell(h, i, bold: true)],
        ),
        for (final r in rows)
          pw.TableRow(
            decoration: r.subtotal ? pw.BoxDecoration(color: _subtotalBg) : null,
            children: [for (final (i, v) in r.cells.indexed) cell(v, i, bold: r.subtotal)],
          ),
      ],
    );
  }

  pw.Widget _empty(String text) => pw.Text(text, style: pw.TextStyle(fontSize: 8, color: _muted));

  /// 2026-10-28 → 28.10.2026
  static String _date(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
  }
}

class _Row {
  final List<String> cells;
  final bool subtotal;

  const _Row(this.cells, {this.subtotal = false});
}
