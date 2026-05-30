import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_analytics_entity.dart';

enum _ViewMode { chart, list }

class AnalyticsDimensionSection extends StatefulWidget {
  final String title;
  final List<AnalyticsDimensionItem> items;
  final Color accentColor;

  const AnalyticsDimensionSection({
    super.key,
    required this.title,
    required this.items,
    this.accentColor = AppColors.primary,
  });

  @override
  State<AnalyticsDimensionSection> createState() =>
      _AnalyticsDimensionSectionState();
}

class _AnalyticsDimensionSectionState
    extends State<AnalyticsDimensionSection> {
  _ViewMode _mode = _ViewMode.chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                _ToggleButtons(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (widget.items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Ma\'lumot mavjud emas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _mode == _ViewMode.chart
                  ? _ChartView(
                      key: const ValueKey('chart'),
                      items: widget.items,
                      accentColor: widget.accentColor,
                    )
                  : _ListView(
                      key: const ValueKey('list'),
                      items: widget.items,
                      accentColor: widget.accentColor,
                    ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Toggle ────────────────────────────────────────────────────────────────────

class _ToggleButtons extends StatelessWidget {
  final _ViewMode mode;
  final ValueChanged<_ViewMode> onChanged;

  const _ToggleButtons({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ToggleBtn(
          icon: Icons.bar_chart_rounded,
          active: mode == _ViewMode.chart,
          onTap: () => onChanged(_ViewMode.chart),
        ),
        const SizedBox(width: 2),
        _ToggleBtn(
          icon: Icons.format_list_bulleted_rounded,
          active: mode == _ViewMode.list,
          onTap: () => onChanged(_ViewMode.list),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: active ? AppColors.primary : AppColors.textSecondary,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

// ── Bar Chart View ────────────────────────────────────────────────────────────

class _ChartView extends StatelessWidget {
  final List<AnalyticsDimensionItem> items;
  final Color accentColor;

  const _ChartView({super.key, required this.items, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    // Show top 8 to keep the chart readable
    final display = items.take(8).toList();
    final maxY = display
            .map((e) => e.totalQuantity.toDouble())
            .reduce((a, b) => a > b ? a : b) *
        1.2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY > 0 ? maxY : 10,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) {
                  final name = display[group.x].name;
                  return BarTooltipItem(
                    '$name\n${rod.toY.toInt()} dona',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
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
                  reservedSize: 32,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= display.length) {
                      return const SizedBox.shrink();
                    }
                    final label = display[idx].name;
                    final short = label.length > 8
                        ? '${label.substring(0, 7)}…'
                        : label;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        short,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
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
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.divider, strokeWidth: 1),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: AppColors.divider),
                left:   BorderSide(color: AppColors.divider),
              ),
            ),
            barGroups: display.asMap().entries.map((entry) {
              final opacity = 1.0 - (entry.key * 0.07).clamp(0.0, 0.45);
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.totalQuantity.toDouble(),
                    color: accentColor.withValues(alpha: opacity),
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── List View ─────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final List<AnalyticsDimensionItem> items;
  final Color accentColor;

  const _ListView({super.key, required this.items, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < items.length; index++) ...[
          if (index > 0)
            const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[index].name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${items[index].totalQuantity} dona',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${items[index].percentage}%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: items[index].percentage / 100,
                    backgroundColor: accentColor.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation(accentColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
