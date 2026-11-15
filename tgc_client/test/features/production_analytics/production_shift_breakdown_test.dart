import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tgc_client/features/production_analytics/data/models/production_operations_model.dart';
import 'package:tgc_client/features/production_analytics/domain/entities/production_analytics_entity.dart';
import 'package:tgc_client/features/production_analytics/domain/production_shift_breakdown.dart';
import 'package:tgc_client/features/production_analytics/presentation/services/production_report_pdf_exporter.dart';
import 'package:tgc_client/features/production_analytics/presentation/widgets/production_report_pdf_button.dart';
import 'package:tgc_client/features/production_analytics/presentation/widgets/production_shift_breakdown_section.dart';

Map<String, dynamic> _shift(int id, String name, int qty) => {
      'id': id,
      'name': name,
      'total_quantity': qty,
      'total_sqm': qty * 6.0,
      'working_days': 2,
      'avg_quantity_per_day': qty / 2,
      'avg_sqm_per_day': qty * 3.0,
      'best_day_quantity': qty,
      'best_day_quantity_date': '2026-10-01',
      'best_day_sqm': qty * 6.0,
      'best_day_sqm_date': '2026-10-01',
      'utilization_quantity': 50.0,
      'utilization_sqm': 50.0,
      'total_defects': 0,
      'defect_rate': 0.0,
      'reprints': 0,
      'over_target_prints': 0,
    };

final _json = <String, dynamic>{
  'period': {'from': '2026-10-01', 'to': '2026-10-31', 'trend_by': 'day'},
  'day_start_hour': 8,
  'summary': {..._shift(0, '', 30), 'period_days': 31, 'backfilled_excluded': 0},
  'trend': <dynamic>[],
  'heatmap': <dynamic>[],
  'by_machine': [_shift(1, 'Stanok 1', 30)],
  // Order of by_shift (most output first) decides the order of the groups.
  'by_shift': [
    _shift(5, '1 SMENA (YORLIQ)', 20),
    _shift(6, '2 SMENA (YORLIQ)', 10),
  ],
  'by_shift_quality': [
    {'user_id': 6, 'quality_id': 2, 'quality_name': 'Lux', 'total_quantity': 10, 'total_sqm': 60.0},
    {'user_id': 5, 'quality_id': 1, 'quality_name': 'Standart', 'total_quantity': 4, 'total_sqm': 24.0},
    {'user_id': 5, 'quality_id': 2, 'quality_name': 'Lux', 'total_quantity': 16, 'total_sqm': 96.0},
  ],
  'by_shift_width': [
    {'user_id': 5, 'width': 400, 'total_quantity': 2, 'total_sqm': 180.0},
    {'user_id': 5, 'width': 150, 'total_quantity': 1, 'total_sqm': 37.5},
    {'user_id': 9, 'width': 300, 'total_quantity': 1, 'total_sqm': 90.0},
  ],
};

ProductionAnalyticsEntity _entity(Map<String, dynamic> json) => ProductionAnalyticsEntity(
      periodFrom: '2026-10-01',
      periodTo: '2026-10-31',
      trendBy: 'day',
      summary: const ProductionAnalyticsSummary(totalBatches: 3, totalProduced: 30, totalSqm: 180),
      trend: const [],
      byType: const [],
      byColor: const [],
      bySize: const [],
      byQuality: const [],
      byEdge: const [],
      operations: ProductionOperationsModel.fromJson(json),
    );

/// The app's own font, read from disk: tests have no asset bundle.
Future<pw.ThemeData> _onest() async => pw.ThemeData.withFont(
      base: pw.Font.ttf(ByteData.sublistView(File('fonts/Onest-Regular.ttf').readAsBytesSync())),
      bold: pw.Font.ttf(ByteData.sublistView(File('fonts/Onest-Bold.ttf').readAsBytesSync())),
    );

void main() {
  test('parses quality and width rows; an older server without them gives empty lists', () {
    final ops = ProductionOperationsModel.fromJson(_json);
    expect(ops.byShiftQuality, hasLength(3));
    expect(ops.byShiftQuality.first.qualityName, 'Lux');
    expect(ops.byShiftWidth.first.width, 400);

    final old = ProductionOperationsModel.fromJson({..._json}
      ..remove('by_shift_quality')
      ..remove('by_shift_width'));
    expect(old.byShiftQuality, isEmpty);
    expect(old.byShiftWidth, isEmpty);
  });

  test('groups follow the shift order, qualities by count, widths narrowest first', () {
    final ops = ProductionOperationsModel.fromJson(_json);

    final q = shiftQualityGroups(ops);
    expect(q.map((g) => g.shiftName), ['1 SMENA (YORLIQ)', '2 SMENA (YORLIQ)']);
    expect(q.first.lines.map((l) => l.label), ['Lux', 'Standart']);
    expect(q.first.totalQuantity, 20);
    expect(q.first.totalSqm, 120.0);

    final w = shiftWidthGroups(ops);
    // User 9 is not in by_shift: still shown, after the known shifts.
    expect(w.map((g) => g.shiftName), ['1 SMENA (YORLIQ)', 'Noma\'lum']);
    expect(w.first.lines.map((l) => l.label), ['1.5 m', '4 m']);
    expect(w.first.totalQuantity, 3);
  });

  test('number formatting groups thousands', () {
    expect(formatQty(1234567), '1 234 567');
    expect(formatSqm(1234.56), '1 234.6');
    expect(formatSqm(0), '0.0');
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('sections render at ${width.toInt()}px with subtotals and an empty state', (tester) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final ops = ProductionOperationsModel.fromJson(_json);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [
            ProductionShiftBreakdownSection(
              title: 'Smenalar — sifat bo\'yicha',
              icon: Icons.layers_outlined,
              lineHeader: 'Sifat',
              groups: shiftQualityGroups(ops),
              emptyText: 'yo\'q',
            ),
            ProductionShiftBreakdownSection(
              title: 'Kovrolin',
              icon: Icons.straighten_rounded,
              lineHeader: 'Eni',
              countHeader: 'Rulon',
              groups: const [],
              emptyText: 'Bu davrda Kovrolin ishlab chiqarilmagan.',
            ),
          ]),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('1 SMENA (YORLIQ)'), findsOneWidget);
      expect(find.text('Standart'), findsOneWidget);
      expect(find.text('Jami'), findsOneWidget, reason: 'only the shift with two qualities gets a subtotal');
      expect(find.text('Hammasi'), findsOneWidget);
      expect(find.text('30'), findsOneWidget, reason: 'grand total of carpets');
      expect(find.text('180.0'), findsOneWidget, reason: 'grand total m²');
      expect(find.text('Bu davrda Kovrolin ishlab chiqarilmagan.'), findsOneWidget);
    });
  }

  test('PDF has every table, in the app font', () async {
    final bytes = await ProductionReportPdfExporter(theme: _onest)
        .export(_entity(_json), generatedAt: DateTime(2026, 11, 15, 9, 30));

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(10000), reason: 'the font is embedded');

    // PDF_OUT=/path/report.pdf flutter test … keeps the file for a look.
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('PDF still builds without operations data', () async {
    final data = _entity(_json);
    final bare = ProductionAnalyticsEntity(
      periodFrom: data.periodFrom,
      periodTo: data.periodTo,
      trendBy: data.trendBy,
      summary: data.summary,
      trend: const [],
      byType: const [],
      byColor: const [],
      bySize: const [],
      byQuality: const [],
      byEdge: const [],
    );
    final bytes = await ProductionReportPdfExporter(theme: _onest).export(bare);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  testWidgets('the button saves a PDF named after the period on screen', (tester) async {
    Uint8List? saved;
    String? name;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [
          ProductionReportPdfButton(
            data: _entity(_json),
            exporter: ProductionReportPdfExporter(theme: _onest),
            saver: (bytes, fileName) async {
              saved = bytes;
              name = fileName;
              return '/tmp/$fileName';
            },
          ),
        ]),
      ),
    ));

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('PDF yuklab olish'));
      for (var i = 0; i < 50 && saved == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();

    expect(name, 'Ishlab_chiqarish_2026-10-01_2026-10-31.pdf');
    expect(String.fromCharCodes(saved!.take(5)), '%PDF-');
    expect(find.text('Saqlandi: /tmp/Ishlab_chiqarish_2026-10-01_2026-10-31.pdf'), findsOneWidget);
  });
}
