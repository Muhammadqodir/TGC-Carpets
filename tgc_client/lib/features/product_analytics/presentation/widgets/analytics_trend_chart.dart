import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/stacked_bar_chart.dart';
import '../../domain/entities/product_analytics_entity.dart';

/// Ordered carpets per day (or week / month) as bars, totals on top, the
/// same look as the production charts. Hover or tap a bar for the date
/// and the number of orders.
class AnalyticsTrendChart extends StatelessWidget {
  final List<AnalyticsTrendPoint> trend;
  final String trendBy;
  final String periodFrom;
  final String periodTo;
  final AnalyticsMetric metric;

  const AnalyticsTrendChart({
    super.key,
    required this.trend,
    required this.trendBy,
    required this.periodFrom,
    required this.periodTo,
    this.metric = AnalyticsMetric.quantity,
  });

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Ma\'lumot mavjud emas',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final byLabel = {for (final t in trend) t.label: t};
    final buckets = {...TrendLabels.allDays(trendBy, periodFrom, periodTo), ...byLabel.keys}
        .toList()
      ..sort();

    return StackedBarChart(
      axisLabels: [for (final b in buckets) TrendLabels.short(b, trendBy)],
      titles: [for (final b in buckets) TrendLabels.long(b, trendBy)],
      notes: [
        for (final b in buckets)
          (byLabel[b]?.ordersCount ?? 0) > 0 ? '${byLabel[b]!.ordersCount} ta buyurtma' : '',
      ],
      values: [
        for (final b in buckets) {0: byLabel[b]?.valueOf(metric) ?? 0},
      ],
      series: const [0],
      names: const {0: 'Buyurtmalar'},
      format: metric.format,
      decimals: metric == AnalyticsMetric.sqm,
    );
  }
}
