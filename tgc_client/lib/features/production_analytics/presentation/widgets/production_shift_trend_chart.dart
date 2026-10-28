import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';
import 'production_stacked_bar_chart.dart';

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

  static const _weekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

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
    final values = <String, Map<int, double>>{for (final l in _labels()) l: {}};
    for (final t in trend) {
      final bucket = values.putIfAbsent(t.label, () => {});
      bucket[t.userId] = (bucket[t.userId] ?? 0) + t.valueOf(metric);
    }
    final buckets = values.keys.toList()..sort();

    return ProductionStackedBarChart(
      axisLabels: [for (final b in buckets) _shortLabel(b)],
      titles: [for (final b in buckets) _longLabel(b)],
      values: [for (final b in buckets) values[b]!],
      series: ProductionStackedBarChart.seriesOf(trend.map((t) => t.userId), names),
      names: names,
      metric: metric,
    );
  }

  /// Every day of the period for a daily chart, so a day with no output
  /// shows as a gap instead of disappearing.
  List<String> _labels() {
    if (trendBy != 'day') return const [];
    final from = DateTime.tryParse(periodFrom);
    final to = DateTime.tryParse(periodTo);
    if (from == null || to == null) return const [];
    return [
      for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1))
        '${d.year}-${_two(d.month)}-${_two(d.day)}',
    ];
  }

  String _shortLabel(String raw) {
    if (trendBy == 'day' && raw.length == 10) {
      return '${raw.substring(8)}.${raw.substring(5, 7)}';
    }
    if (trendBy == 'week') return '${raw.split('-').last}-h';
    if (trendBy == 'month' && raw.length == 7) {
      return '${raw.substring(5)}.${raw.substring(2, 4)}';
    }
    return raw;
  }

  String _longLabel(String raw) {
    if (trendBy == 'day') {
      final d = DateTime.tryParse(raw);
      if (d != null) {
        return '${_two(d.day)}.${_two(d.month)}.${d.year}, ${_weekdays[d.weekday - 1]}';
      }
    }
    if (trendBy == 'week') {
      final p = raw.split('-');
      if (p.length == 2) return '${p[0]}, ${p[1]}-hafta';
    }
    if (trendBy == 'month' && raw.length == 7) {
      return '${raw.substring(5)}.${raw.substring(0, 4)}';
    }
    return raw;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
