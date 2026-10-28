import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/product_analytics/domain/entities/product_analytics_entity.dart';
import 'package:tgc_client/features/production_analytics/data/models/production_operations_model.dart';
import 'package:tgc_client/features/production_analytics/presentation/widgets/production_capacity_section.dart';
import 'package:tgc_client/features/production_analytics/presentation/widgets/production_hourly_heatmap.dart';
import 'package:tgc_client/features/production_analytics/presentation/widgets/production_ops_summary_cards.dart';

Map<String, dynamic> _row(int? id, String name, int qty, {int days = 20, int defects = 0}) => {
      'id': id,
      'name': name,
      'total_quantity': qty,
      'total_sqm': qty * 6.0,
      'working_days': days,
      'avg_quantity_per_day': days > 0 ? qty / days : 0,
      'avg_sqm_per_day': days > 0 ? qty * 6.0 / days : 0,
      'best_day_quantity': days > 0 ? (qty / days * 1.4).round() : 0,
      'best_day_quantity_date': days > 0 ? '2026-10-14' : null,
      'best_day_sqm': days > 0 ? qty * 6.0 / days * 1.5 : 0,
      'best_day_sqm_date': days > 0 ? '2026-10-15' : null,
      'utilization_quantity': days > 0 ? 71.4 : null,
      'utilization_sqm': days > 0 ? 66.7 : null,
      'total_defects': defects,
      'defect_rate': qty + defects > 0 ? defects / (qty + defects) * 100 : null,
      'reprints': days > 0 ? 3 : 0,
      'over_target_prints': days > 0 ? 1 : 0,
    };

final _json = <String, dynamic>{
  'period': {'from': '2026-09-29', 'to': '2026-10-28'},
  'day_start_hour': 8,
  'summary': {
    ..._row(null, '', 2400, days: 26, defects: 31),
    'period_days': 30,
    'backfilled_excluded': 0,
  },
  'by_shift': [
    _row(5, '1 SMENA (YORLIQ)', 1300, days: 26, defects: 0),
    _row(6, '2 SMENA (YORLIQ) juda uzun nomli smena hisobi', 1100, days: 25),
    _row(1, 'Admin', 0, days: 0, defects: 31),
  ],
  'by_machine': [
    _row(1, 'Stanok 1', 1500, defects: 20),
    _row(2, 'Stanok 2', 900, defects: 11),
    _row(3, 'Stanok 3', 0, days: 0),
  ],
  'heatmap': [
    for (var d = 0; d < 7; d++)
      for (var h = 0; h < 24; h++)
        {'user_id': h >= 8 && h < 20 ? 5 : 6, 'weekday': d, 'hour': h, 'total_quantity': (h * 3 + d) % 17, 'total_sqm': ((h * 3 + d) % 17) * 6.0},
  ],
};

void main() {
  test('parses the operations report', () {
    final ops = ProductionOperationsModel.fromJson(_json);
    expect(ops.dayStartHour, 8);
    expect(ops.periodDays, 30);
    expect(ops.summary.totalQuantity, 2400);
    expect(ops.byShift.first.name, '1 SMENA (YORLIQ)');
    expect(ops.byShift.last.utilizationQuantity, isNull);
    expect(ops.byMachine[2].bestDayQuantityDate, isNull);
    expect(ops.heatmap, hasLength(168));
    expect(ops.summary.extraPrints, 4);
    expect(ops.byMachine[2].extraPrints, 0);
  });

  for (final width in [360.0, 1280.0]) {
    for (final metric in AnalyticsMetric.values) {
      testWidgets('renders without overflow at ${width.toInt()}px, ${metric.name}', (tester) async {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final ops = ProductionOperationsModel.fromJson(_json);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ProductionOpsSummaryCards(ops: ops, metric: metric),
                ProductionCapacitySection(
                  title: 'Smenalar',
                  rows: ops.byShift,
                  metric: metric,
                  icon: Icons.groups_2_outlined,
                ),
                ProductionCapacitySection(
                  title: 'Stanoklar',
                  rows: ops.byMachine,
                  metric: metric,
                  icon: Icons.precision_manufacturing_outlined,
                ),
                ProductionHourlyHeatmap(cells: ops.heatmap, shifts: ops.byShift, metric: metric),
              ],
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(find.text('Bu davrda ishlamagan'), findsOneWidget);

        // Filtering the heatmap to one shift.
        await tester.tap(find.text('1 SMENA (YORLIQ)').last);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
