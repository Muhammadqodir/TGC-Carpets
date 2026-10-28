import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';
import 'production_shift_trend_chart.dart';

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
    final series = ProductionShiftTrendChart.seriesOf(cells.map((c) => c.userId), names);
    final colorOf = ProductionShiftTrendChart.colorsOf(series);

    // The API splits by weekday too; this chart only needs the hour.
    final byHour = List.generate(24, (_) => <int, double>{});
    for (final c in cells) {
      if (c.hour < 0 || c.hour > 23) continue;
      byHour[c.hour][c.userId] = (byHour[c.hour][c.userId] ?? 0) + c.valueOf(metric);
    }
    final totals = [for (final h in byHour) h.values.fold<double>(0, (s, v) => s + v)];
    final maxTotal = totals.fold<double>(0, (m, v) => v > m ? v : m);
    final step = ProductionShiftTrendChart.niceStep(maxTotal * 1.1 / 4);
    final maxY = maxTotal > 0 ? (maxTotal * 1.1 / step).ceil() * step : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductionShiftTrendChart.legend(series, names, colorOf),
        LayoutBuilder(
          builder: (context, c) {
            final slot = (c.maxWidth - 40) / 24;
            final barWidth = (slot * 0.7).clamp(3.0, 28.0);
            // Every hour when there is room, every other one on a phone.
            final every = slot >= 16 ? 1 : 2;

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
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: step,
                        getTitlesWidget: (v, _) => Text(
                          v.round().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) {
                          final h = v.toInt();
                          if (h < 0 || h > 23 || h % every != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _two(h),
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var h = 0; h < 24; h++)
                      BarChartGroupData(
                        x: h,
                        barRods: [
                          BarChartRodData(
                            toY: totals[h],
                            width: barWidth,
                            color: Colors.transparent,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            rodStackItems: ProductionShiftTrendChart.stack(byHour[h], series, colorOf),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary.withAlpha(235),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      maxContentWidth: 280,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      getTooltipItem: (group, _, __, ___) {
                        final h = group.x;
                        final v = byHour[h];
                        return BarTooltipItem(
                          '${_two(h)}:00 – ${_two(h)}:59\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          textAlign: TextAlign.left,
                          children: [
                            for (final id in series)
                              if ((v[id] ?? 0) > 0)
                                TextSpan(
                                  text: '${names[id] ?? 'Noma\'lum'}: ',
                                  style: TextStyle(
                                    color: Color.lerp(colorOf[id], Colors.white, 0.35),
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
                              text: 'Jami: ${metric.format(totals[h])}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
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

  static String _two(int n) => n.toString().padLeft(2, '0');
}
