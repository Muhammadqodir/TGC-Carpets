import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/stacked_bar_chart.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';

/// Output per production day (or week / month), one stacked bar per
/// period with a segment for each shift. Hover or tap a bar for the date
/// and each shift's share.
class ProductionShiftTrendChart extends StatelessWidget {
  final List<ProductionShiftTrendPoint> trend;
  final List<ProductionCapacityStats> shifts;
  final String trendBy;
  final String periodFrom;
  final String periodTo;
  final AnalyticsMetric metric;

  const ProductionShiftTrendChart({
    super.key,
    required this.trend,
    required this.shifts,
    required this.trendBy,
    required this.periodFrom,
    required this.periodTo,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Ma\'lumot mavjud emas', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final names = {for (final s in shifts) if (s.id != null) s.id!: s.name};
    final values = <String, Map<int, double>>{
      for (final l in TrendLabels.allDays(trendBy, periodFrom, periodTo)) l: {},
    };
    for (final t in trend) {
      final bucket = values.putIfAbsent(t.label, () => {});
      bucket[t.userId] = (bucket[t.userId] ?? 0) + t.valueOf(metric);
    }
    final buckets = values.keys.toList()..sort();

    return StackedBarChart(
      axisLabels: [for (final b in buckets) TrendLabels.short(b, trendBy)],
      titles: [for (final b in buckets) TrendLabels.long(b, trendBy)],
      values: [for (final b in buckets) values[b]!],
      series: StackedBarChart.seriesOf(trend.map((t) => t.userId), names),
      names: names,
      format: metric.format,
      decimals: metric == AnalyticsMetric.sqm,
    );
  }
}
