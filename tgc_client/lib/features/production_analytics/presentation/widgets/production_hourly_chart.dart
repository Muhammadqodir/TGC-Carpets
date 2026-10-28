import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/stacked_bar_chart.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';

/// Labels printed per clock hour over the whole period, stacked by shift
/// in the same colours as the trend chart. Shows when the floor is busy,
/// when it stalls, and how the hand-over between shifts goes.
class ProductionHourlyChart extends StatelessWidget {
  final List<ProductionHeatmapCell> cells;
  final List<ProductionCapacityStats> shifts;
  final AnalyticsMetric metric;

  const ProductionHourlyChart({
    super.key,
    required this.cells,
    required this.shifts,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Ma\'lumot mavjud emas', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final names = {for (final s in shifts) if (s.id != null) s.id!: s.name};

    // The API splits by weekday too; this chart only needs the hour.
    final byHour = List.generate(24, (_) => <int, double>{});
    for (final c in cells) {
      if (c.hour < 0 || c.hour > 23) continue;
      byHour[c.hour][c.userId] = (byHour[c.hour][c.userId] ?? 0) + c.valueOf(metric);
    }

    return StackedBarChart(
      axisLabels: [for (var h = 0; h < 24; h++) _two(h)],
      titles: [for (var h = 0; h < 24; h++) '${_two(h)}:00 – ${_two(h)}:59'],
      values: byHour,
      series: StackedBarChart.seriesOf(cells.map((c) => c.userId), names),
      names: names,
      format: metric.format,
      decimals: metric == AnalyticsMetric.sqm,
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
