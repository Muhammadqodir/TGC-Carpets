import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../product_analytics/domain/entities/product_analytics_entity.dart';

class ProductionAnalyticsSummaryCards extends StatelessWidget {
  final int totalBatches;
  final int totalProduced;
  final double totalSqm;
  final AnalyticsMetric metric;

  const ProductionAnalyticsSummaryCards({
    super.key,
    required this.totalBatches,
    required this.totalProduced,
    required this.totalSqm,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Jami partiyalar',
                value: totalBatches.toString(),
                icon: Icons.precision_manufacturing_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Jami ishlab chiqarilgan',
                value: metric == AnalyticsMetric.quantity
                    ? '$totalProduced dona'
                    : '${totalSqm.toStringAsFixed(1)} m²',
                icon: Icons.inventory_2_outlined,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Half a phone's width: tighter, so the label still reads in full.
    final compact = MediaQuery.sizeOf(context).width < 480;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 7 : 10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: compact ? 18 : 22),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  // One line, also when the row measures its height.
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
