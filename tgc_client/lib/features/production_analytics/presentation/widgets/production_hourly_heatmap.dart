import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';

/// Labels printed per weekday × clock hour, optionally for one shift,
/// with an hourly total underneath. Shows when the floor is busy, when it
/// stalls, and how the hand-over between shifts goes.
class ProductionHourlyHeatmap extends StatefulWidget {
  final List<ProductionHeatmapCell> cells;
  final List<ProductionCapacityStats> shifts;
  final AnalyticsMetric metric;

  const ProductionHourlyHeatmap({
    super.key,
    required this.cells,
    required this.shifts,
    required this.metric,
  });

  @override
  State<ProductionHourlyHeatmap> createState() => _ProductionHourlyHeatmapState();
}

class _ProductionHourlyHeatmapState extends State<ProductionHourlyHeatmap> {
  /// null = every shift.
  int? _userId;

  static const _weekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _labelWidth = 26.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metric = widget.metric;
    final printers = widget.cells.map((c) => c.userId).toSet();
    final shifts = widget.shifts.where((s) => s.id != null && printers.contains(s.id)).toList();
    final selected = shifts.any((s) => s.id == _userId) ? _userId : null;

    final grid = List.generate(7, (_) => List<double>.filled(24, 0));
    for (final c in widget.cells) {
      if (selected != null && c.userId != selected) continue;
      if (c.weekday < 0 || c.weekday > 6 || c.hour < 0 || c.hour > 23) continue;
      grid[c.weekday][c.hour] += c.valueOf(metric);
    }
    final byHour = List<double>.generate(24, (h) => grid.fold(0.0, (s, row) => s + row[h]));
    final maxCell = grid.expand((r) => r).fold<double>(0, (m, v) => v > m ? v : m);
    final maxHour = byHour.fold<double>(0, (m, v) => v > m ? v : m);
    final small = theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, fontSize: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shifts.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('Hammasi'),
                  selected: selected == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _userId = null),
                ),
                for (final s in shifts)
                  ChoiceChip(
                    label: Text(s.name),
                    selected: selected == s.id,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _userId = s.id),
                  ),
              ],
            ),
          ),
        if (maxCell == 0)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text('Ma\'lumot mavjud emas', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
            child: LayoutBuilder(
              builder: (context, c) {
                final cellW = (c.maxWidth - _labelWidth) / 24;
                final cellH = cellW.clamp(10.0, 22.0);

                Widget hourAxis() => Row(
                      children: [
                        const SizedBox(width: _labelWidth),
                        for (var h = 0; h < 24; h++)
                          SizedBox(
                            width: cellW,
                            child: h % 3 == 0
                                ? Text(h.toString().padLeft(2, '0'), style: small, softWrap: false, overflow: TextOverflow.visible)
                                : null,
                          ),
                      ],
                    );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    hourAxis(),
                    const SizedBox(height: 2),
                    for (var d = 0; d < 7; d++)
                      Row(
                        children: [
                          SizedBox(width: _labelWidth, child: Text(_weekdays[d], style: small)),
                          for (var h = 0; h < 24; h++)
                            Tooltip(
                              message: '${_weekdays[d]}, '
                                  '${h.toString().padLeft(2, '0')}:00–${h.toString().padLeft(2, '0')}:59\n'
                                  '${metric.format(grid[d][h])}',
                              child: Container(
                                width: cellW,
                                height: cellH,
                                padding: const EdgeInsets.all(1),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _shade(grid[d][h], maxCell),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: _labelWidth),
                      child: Text('Soat bo\'yicha jami', style: small),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 48,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const SizedBox(width: _labelWidth),
                          for (var h = 0; h < 24; h++)
                            Tooltip(
                              message: '${h.toString().padLeft(2, '0')}:00 — ${metric.format(byHour[h])}',
                              child: Container(
                                width: cellW,
                                height: maxHour > 0 ? (48 * byHour[h] / maxHour).clamp(1.0, 48.0) : 1,
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: byHour[h] > 0 ? AppColors.primaryLight : AppColors.divider,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    hourAxis(),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  static Color _shade(double v, double max) {
    if (v <= 0 || max <= 0) return AppColors.divider.withAlpha(70);
    final t = (v / max).clamp(0.0, 1.0);
    return Color.lerp(
      AppColors.primaryLight.withAlpha(40),
      AppColors.primary,
      t,
    )!;
  }
}
