import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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

  static const palette = [
    AppColors.primaryLight,
    AppColors.accent,
    Color(0xFF7B5EA7),
    Color(0xFF2196A6),
    Color(0xFFC77B3F),
  ];
  static const _weekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  Widget build(BuildContext context) {
    final names = {
      for (final s in shifts)
        if (s.id != null) s.id!: s.name
    };
    final series = seriesOf(trend.map((t) => t.userId), names);
    final colorOf = colorsOf(series);

    final labels = _labels();
    final values = <String, Map<int, double>>{for (final l in labels) l: {}};
    for (final t in trend) {
      values.putIfAbsent(t.label, () => {});
      values[t.label]![t.userId] =
          (values[t.label]![t.userId] ?? 0) + t.valueOf(metric);
    }
    final buckets = values.keys.toList()..sort();

    if (trend.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Ma\'lumot mavjud emas',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final totals = [
      for (final b in buckets)
        values[b]!.values.fold<double>(0, (s, v) => s + v)
    ];
    final maxTotal = totals.fold<double>(0, (m, v) => v > m ? v : m);
    final step = niceStep(maxTotal * 1.1 / 4);
    final maxY = maxTotal > 0 ? (maxTotal * 1.1 / step).ceil() * step : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        legend(series, names, colorOf),
        LayoutBuilder(
          builder: (context, c) {
            final slot = (c.maxWidth - 40) / buckets.length;
            final barWidth = (slot * 0.7).clamp(2.0, 28.0);
            final every = _labelEvery(buckets.length, c.maxWidth);

            return SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      bottom: BorderSide(color: AppColors.divider),
                      left: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: step,
                        getTitlesWidget: (v, meta) => Text(
                          v.round().toString(),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= buckets.length || i % every != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _shortLabel(buckets[i]),
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: totals[i],
                            width: barWidth,
                            color: Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                            rodStackItems:
                                stack(values[buckets[i]]!, series, colorOf),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          AppColors.textPrimary.withAlpha(235),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: 280,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      getTooltipItem: (group, _, __, ___) {
                        final b = buckets[group.x];
                        final v = values[b]!;
                        return BarTooltipItem(
                          '${_longLabel(b)}\n',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                          textAlign: TextAlign.left,
                          children: [
                            for (final id in series)
                              if ((v[id] ?? 0) > 0)
                                TextSpan(
                                  text: '${names[id] ?? 'Noma\'lum'}: ',
                                  style: TextStyle(
                                    color: Color.lerp(
                                        colorOf[id], Colors.white, 0.35),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '${metric.format(v[id]!)}\n',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                            TextSpan(
                              text: 'Jami: ${metric.format(totals[group.x])}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Colour key for the shift series.
  static Widget legend(
          List<int> series, Map<int, String> names, Map<int, Color> colorOf) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final id in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorOf[id],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      names[id] ?? 'Noma\'lum',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );

  /// Accounts in display order: "1 SMENA" before "2 SMENA", so a shift
  /// keeps its colour across periods and across charts.
  static List<int> seriesOf(Iterable<int> userIds, Map<int, String> names) =>
      userIds.toSet().toList()
        ..sort((a, b) => (names[a] ?? '').compareTo(names[b] ?? ''));

  static Map<int, Color> colorsOf(List<int> series) => {
        for (var i = 0; i < series.length; i++)
          series[i]: palette[i % palette.length],
      };

  static List<BarChartRodStackItem> stack(
      Map<int, double> v, List<int> series, Map<int, Color> colorOf) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final id in series) {
      final val = v[id] ?? 0;
      if (val <= 0) continue;
      items.add(BarChartRodStackItem(from, from + val, colorOf[id]!));
      from += val;
    }
    return items;
  }

  /// Every day of the period for a daily chart, so a day with no output
  /// shows as a gap instead of disappearing.
  List<String> _labels() {
    if (trendBy != 'day') return const [];
    final from = DateTime.tryParse(periodFrom);
    final to = DateTime.tryParse(periodTo);
    if (from == null || to == null) return const [];
    return [
      for (var d = from;
          !d.isAfter(to);
          d = DateTime(d.year, d.month, d.day + 1))
        '${d.year}-${_two(d.month)}-${_two(d.day)}',
    ];
  }

  int _labelEvery(int n, double width) {
    final fit = (width / 44).floor().clamp(1, 1000);
    return (n / fit).ceil().clamp(1, 1000);
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

  /// 1, 2, 2.5 or 5 × 10ⁿ, so the axis reads 0 / 25 / 50 / 75.
  static double niceStep(double raw) {
    if (raw <= 0) return 2.5;
    var mag = 1.0;
    while (mag * 10 <= raw) {
      mag *= 10;
    }
    while (mag > raw) {
      mag /= 10;
    }
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * mag >= raw) return m * mag;
    }
    return 10 * mag;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
