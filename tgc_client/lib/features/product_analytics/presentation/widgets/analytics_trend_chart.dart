import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_analytics_entity.dart';

class AnalyticsTrendChart extends StatelessWidget {
  final List<AnalyticsTrendPoint> trend;
  final String trendBy;

  const AnalyticsTrendChart({
    super.key,
    required this.trend,
    required this.trendBy,
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

    final maxY = trend
            .map((e) => e.totalQuantity.toDouble())
            .reduce((a, b) => a > b ? a : b) *
        1.2;

    final spots = trend.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalQuantity.toDouble());
    }).toList();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: _labelInterval,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= trend.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatLabel(trend[idx].label),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: AppColors.divider),
              left:   BorderSide(color: AppColors.divider),
            ),
          ),
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: maxY > 0 ? maxY : 10,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withAlpha(30),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()} dona',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  double get _labelInterval {
    if (trend.length <= 7) return 1;
    if (trend.length <= 30) return 5;
    if (trend.length <= 60) return 10;
    return (trend.length / 6).roundToDouble();
  }

  String _formatLabel(String raw) {
    // raw is: yyyy-MM-dd | yyyy-WW | yyyy-MM
    if (raw.contains('-') && raw.length == 10) {
      // daily: show MM/dd
      final parts = raw.split('-');
      if (parts.length == 3) return '${parts[1]}/${parts[2]}';
    }
    return raw;
  }
}
