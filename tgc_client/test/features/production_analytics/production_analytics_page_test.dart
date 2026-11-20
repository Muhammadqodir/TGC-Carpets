import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/core/theme/app_theme.dart';
import 'package:tgc_client/features/product_analytics/domain/entities/product_analytics_entity.dart';
import 'package:tgc_client/features/production_analytics/data/models/production_operations_model.dart';
import 'package:tgc_client/features/production_analytics/domain/entities/production_analytics_entity.dart';
import 'package:tgc_client/features/production_analytics/domain/repositories/production_analytics_repository.dart';
import 'package:tgc_client/features/production_analytics/domain/usecases/get_production_analytics_usecase.dart';
import 'package:tgc_client/features/production_analytics/presentation/bloc/production_analytics_bloc.dart';
import 'package:tgc_client/features/production_analytics/presentation/pages/production_analytics_page.dart';
import 'package:tgc_client/features/production_analytics/presentation/widgets/production_shift_trend_chart.dart';

Map<String, dynamic> _row(int? id, String name, int qty, {int days = 26, int defects = 0}) => {
      'id': id,
      'name': name,
      'total_quantity': qty,
      'total_sqm': qty * 6.4,
      'working_days': days,
      'avg_quantity_per_day': days > 0 ? qty / days : 0,
      'avg_sqm_per_day': days > 0 ? qty * 6.4 / days : 0,
      'best_day_quantity': days > 0 ? (qty / days * 1.4).round() : 0,
      'best_day_quantity_date': days > 0 ? '2026-11-14' : null,
      'best_day_sqm': days > 0 ? qty * 6.4 / days * 1.5 : 0,
      'best_day_sqm_date': days > 0 ? '2026-11-15' : null,
      'utilization_quantity': days > 0 ? 71.4 : null,
      'utilization_sqm': days > 0 ? 66.7 : null,
      'total_defects': defects,
      'defect_rate': qty + defects > 0 ? defects / (qty + defects) * 100 : null,
      'reprints': days > 0 ? 3 : 0,
      'over_target_prints': days > 0 ? 1 : 0,
    };

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A month of two shifts, with long quality names and five-digit m² so the
/// tables are as wide as they get on the factory's data.
Map<String, dynamic> _json(String from, String to) {
  final start = DateTime.parse(from);
  final days = DateTime.parse(to).difference(start).inDays + 1;
  return {
    'period': {'from': from, 'to': to, 'trend_by': 'day'},
    'day_start_hour': 8,
    'trend': [
      for (var d = 0; d < days; d++)
        if (d % 7 != 3)
          for (final u in [5, 6])
            {
              'label': _day(start.add(Duration(days: d))),
              'user_id': u,
              'total_quantity': 60 + (d * 7 + u * 13) % 45,
              'total_sqm': (60 + (d * 7 + u * 13) % 45) * 6.4,
            },
    ],
    'summary': {..._row(null, '', 2400, defects: 31), 'period_days': days, 'backfilled_excluded': 12},
    'by_shift': [
      _row(5, '1 SMENA (YORLIQ)', 1300),
      _row(6, '2 SMENA (YORLIQ)', 1100, days: 25),
      _row(1, 'Admin', 0, days: 0, defects: 31),
    ],
    'by_machine': [
      _row(1, 'Stanok 1', 1500, defects: 20),
      _row(2, 'Stanok 2', 900, defects: 11),
    ],
    'heatmap': [
      for (var d = 0; d < 7; d++)
        for (var h = 0; h < 24; h++)
          {
            'user_id': h >= 8 && h < 20 ? 5 : 6,
            'weekday': d,
            'hour': h,
            'total_quantity': 4 + (h * 3 + d) % 17,
            'total_sqm': (4 + (h * 3 + d) % 17) * 6.4,
          },
      // The hand-over hour has both shifts printing.
      {'user_id': 6, 'weekday': 0, 'hour': 8, 'total_quantity': 9, 'total_sqm': 57.6},
    ],
    'by_shift_quality': [
      {'user_id': 5, 'quality_id': 1, 'quality_name': 'Standart', 'total_quantity': 1250, 'total_sqm': 12345.6},
      {'user_id': 5, 'quality_id': 2, 'quality_name': 'Lux Premium Jakkard', 'total_quantity': 50, 'total_sqm': 320.0},
      {'user_id': 6, 'quality_id': 1, 'quality_name': 'Standart', 'total_quantity': 1100, 'total_sqm': 7040.0},
    ],
    'by_shift_width': [
      {'user_id': 5, 'width': 400, 'total_quantity': 12, 'total_sqm': 1080.0},
      {'user_id': 5, 'width': 150, 'total_quantity': 3, 'total_sqm': 112.5},
      {'user_id': 6, 'width': 300, 'total_quantity': 4, 'total_sqm': 360.0},
    ],
  };
}

class _FakeRepository implements ProductionAnalyticsRepository {
  @override
  Future<Either<Failure, ProductionAnalyticsEntity>> getAnalytics({
    required String periodFrom,
    required String periodTo,
    required String trendBy,
  }) async =>
      Right(ProductionAnalyticsEntity(
        periodFrom: periodFrom,
        periodTo: periodTo,
        trendBy: trendBy,
        summary: const ProductionAnalyticsSummary(totalBatches: 148, totalProduced: 12450, totalSqm: 79680.5),
        trend: const [],
        byType: const [],
        byColor: const [],
        bySize: const [],
        byQuality: const [],
        byEdge: const [],
        operations: ProductionOperationsModel.fromJson(_json(periodFrom, periodTo)),
      ));
}

/// SHOT_DIR=/some/dir ICON_FONT=$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf
/// flutter test test/features/production_analytics/production_analytics_page_test.dart
/// also writes the rendered page as PNGs, in the app font, for a look.
final _shotDir = Platform.environment['SHOT_DIR'];

Future<void> _loadFonts() async {
  final onest = FontLoader('Onest');
  for (final f in ['Onest-Regular.ttf', 'Onest-Light.ttf', 'Onest-Bold.ttf']) {
    onest.addFont(Future.value(ByteData.sublistView(File('fonts/$f').readAsBytesSync())));
  }
  await onest.load();
  final icons = Platform.environment['ICON_FONT'];
  if (icons != null) {
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(File(icons).readAsBytesSync()))))
        .load();
  }
}

void main() {
  final shotKey = GlobalKey();

  setUpAll(() async {
    if (_shotDir != null) await _loadFonts();
  });

  setUp(() {
    sl.registerFactory<ProductionAnalyticsBloc>(
      () => ProductionAnalyticsBloc(getAnalyticsUseCase: GetProductionAnalyticsUseCase(_FakeRepository())),
    );
  });

  tearDown(() => sl.reset());

  for (final width in [360.0, 412.0, 768.0, 1280.0]) {
    testWidgets('the whole page lays out without overflow at ${width.toInt()}px', (tester) async {
      // Tall enough that the whole page is laid out, not just one screen.
      tester.view.physicalSize = Size(width, 4200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(RepaintBoundary(
        key: shotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const ProductionAnalyticsPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Smenalar — sifat bo\'yicha'), findsOneWidget);
      expect(find.text('Lux Premium Jakkard'), findsOneWidget);
      expect(find.text('Hammasi'), findsNWidgets(2), reason: 'both shift tables end in a grand total');
      // A phone gives the shift a heading row instead of a column.
      expect(find.text('Smena'), width < 520 ? findsNothing : findsNWidgets(2));
      // Side by side: every day has a bar per shift.
      final groups = tester.widget<BarChart>(find.byType(BarChart).first).data.barGroups;
      expect(groups.every((g) => g.barRods.length == 2), isTrue);

      if (_shotDir != null) {
        await tester.runAsync(() async {
          final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$_shotDir/production_page_${width.toInt()}.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    });
  }

  testWidgets('a long custom range scrolls sideways on a phone, opening on the latest days', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ops = ProductionOperationsModel.fromJson(_json('2026-09-21', '2026-11-20'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ProductionShiftTrendChart(
              trend: ops.trend,
              shifts: ops.byShift,
              trendBy: 'day',
              periodFrom: '2026-09-21',
              periodTo: '2026-11-20',
              metric: AnalyticsMetric.quantity,
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(tester.getRect(find.text('21.09')).right, lessThan(0),
        reason: 'the first day is off to the left until scrolled back');

    await tester.drag(find.byType(BarChart), const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('21.09')).dx, greaterThan(0));
  });
}
