import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';
import '../../domain/entities/production_operations_entity.dart';

/// Factory-wide pace: average working day, best day, how close the
/// average runs to it, defects and labels printed without counting.
class ProductionOpsSummaryCards extends StatelessWidget {
  final ProductionOperationsEntity ops;
  final AnalyticsMetric metric;

  const ProductionOpsSummaryCards({super.key, required this.ops, required this.metric});

  @override
  Widget build(BuildContext context) {
    final s = ops.summary;
    final util = s.utilizationOf(metric);
    final bestDate = s.bestDateOf(metric);

    final tiles = [
      _Tile(
        label: 'O\'rtacha kunlik',
        value: metric.format(s.avgOf(metric)),
        caption: '${s.workingDays} / ${ops.periodDays} ish kuni',
        icon: Icons.speed_rounded,
        color: AppColors.primaryLight,
      ),
      _Tile(
        label: 'Eng yaxshi kun',
        value: metric.format(s.bestOf(metric)),
        caption: bestDate != null ? _date(bestDate) : '—',
        icon: Icons.emoji_events_outlined,
        color: AppColors.accent,
      ),
      _Tile(
        label: 'Quvvatdan foydalanish',
        value: util != null ? '${util.toStringAsFixed(0)}%' : '—',
        caption: 'o\'rtacha ÷ eng yaxshi kun',
        icon: Icons.donut_large_rounded,
        color: AppColors.success,
      ),
      _Tile(
        label: 'Brak',
        value: s.defectRate != null ? '${s.defectRate!.toStringAsFixed(1)}%' : '—',
        caption: '${s.totalDefects} dona',
        icon: Icons.report_gmailerrorred_rounded,
        color: AppColors.error,
      ),
      _Tile(
        label: 'Qayta chop etilgan',
        value: '${s.extraPrints}',
        caption: 'yorliq',
        icon: Icons.print_outlined,
        color: AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth > 900 ? 5 : (c.maxWidth > 560 ? 3 : 2);
        const gap = 12.0;
        // Tiles in a row share its height (a label may take two lines on
        // a phone), and a last row that is short widens its tiles.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i += perRow) ...[
              if (i > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + perRow && j < tiles.length; j++) ...[
                      if (j > i) const SizedBox(width: gap),
                      Expanded(child: tiles[j]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _date(String ymd) =>
      ymd.length < 10 ? ymd : '${ymd.substring(8, 10)}.${ymd.substring(5, 7)}.${ymd.substring(0, 4)}';
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _Tile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // One line, also when the row measures its height.
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
