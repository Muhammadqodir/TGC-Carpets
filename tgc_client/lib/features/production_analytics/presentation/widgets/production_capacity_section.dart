import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';

/// Output against capacity, one row per shift or machine.
///
/// Every row's bar is drawn on one shared scale (the highest best day in
/// the list): the pale part is that row's own best day, the solid part its
/// average working day. Long pale tail = runs well below what it has
/// shown it can do.
class ProductionCapacitySection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ProductionCapacityStats> rows;
  final AnalyticsMetric metric;
  final Color accentColor;
  final IconData icon;

  const ProductionCapacitySection({
    super.key,
    required this.title,
    this.subtitle,
    required this.rows,
    required this.metric,
    required this.icon,
    this.accentColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = rows.fold<double>(0, (m, r) => r.bestOf(metric) > m ? r.bestOf(metric) : m);
    final total = rows.fold<double>(0, (s, r) => s + r.totalOf(metric));

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 8),
          const _Legend(),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                'Ma\'lumot mavjud emas',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.divider),
              _CapacityRow(
                row: rows[i],
                metric: metric,
                scale: scale,
                share: total > 0 ? rows[i].totalOf(metric) / total * 100 : 0,
                color: accentColor,
              ),
            ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);
    Widget swatch(Color c) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            swatch(AppColors.primaryLight),
            const SizedBox(width: 4),
            Text('Kunlik o\'rtacha', style: style),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            swatch(AppColors.primaryLight.withAlpha(50)),
            const SizedBox(width: 4),
            Text('Eng yaxshi kun (quvvat)', style: style),
          ]),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  final ProductionCapacityStats row;
  final AnalyticsMetric metric;
  final double scale;
  final double share;
  final Color color;

  const _CapacityRow({
    required this.row,
    required this.metric,
    required this.scale,
    required this.share,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idle = row.workingDays == 0;
    final util = row.utilizationOf(metric);
    final best = row.bestOf(metric);
    final avg = row.avgOf(metric);
    final secondary = theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: idle ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                metric.format(row.totalOf(metric)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (!idle) ...[
                const SizedBox(width: 6),
                Text('${share.toStringAsFixed(1)}%', style: secondary),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (idle && row.totalDefects == 0 && row.extraPrints == 0)
            Text('Bu davrda ishlamagan', style: secondary)
          else ...[
            if (!idle) _CapacityBar(avg: avg, best: best, scale: scale),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (!idle) ...[
                  _Stat(label: 'O\'rtacha/kun', value: metric.format(avg)),
                  _Stat(
                    label: 'Eng yaxshi',
                    value: '${metric.format(best)}${_date(row.bestDateOf(metric))}',
                  ),
                  if (util != null)
                    _Stat(
                      label: 'Quvvatdan',
                      value: '${util.toStringAsFixed(0)}%',
                      color: _utilColor(util),
                    ),
                  _Stat(label: 'Ish kuni', value: '${row.workingDays}'),
                ],
                if (row.totalDefects > 0)
                  _Stat(
                    label: 'Brak',
                    // A rate only means something next to output: someone
                    // who only recorded defects would read as 100%.
                    value: row.defectRate != null && !idle
                        ? '${row.totalDefects} · ${row.defectRate!.toStringAsFixed(1)}%'
                        : '${row.totalDefects}',
                    color: AppColors.error,
                  ),
                if (row.extraPrints > 0)
                  _Stat(
                    label: 'Qayta chop',
                    value: row.overTargetPrints > 0
                        ? '${row.reprints} + ${row.overTargetPrints} ortiqcha'
                        : '${row.reprints}',
                    color: AppColors.warning,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _date(String? ymd) {
    if (ymd == null || ymd.length < 10) return '';
    return ' (${ymd.substring(8, 10)}.${ymd.substring(5, 7)})';
  }

  static Color _utilColor(double util) {
    if (util >= 80) return AppColors.success;
    if (util >= 60) return AppColors.warning;
    return AppColors.error;
  }
}

class _CapacityBar extends StatelessWidget {
  final double avg;
  final double best;
  final double scale;

  const _CapacityBar({required this.avg, required this.best, required this.scale});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final bestW = scale > 0 ? w * (best / scale) : 0.0;
        final avgW = scale > 0 ? w * (avg / scale) : 0.0;
        return SizedBox(
          height: 10,
          child: Stack(
            children: [
              Container(
                width: w,
                decoration: BoxDecoration(
                  color: AppColors.divider.withAlpha(90),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Container(
                width: bestW,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(50),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Container(
                width: avgW,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withAlpha(14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: value,
            style: TextStyle(color: c, fontWeight: FontWeight.w600),
          ),
        ]),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
