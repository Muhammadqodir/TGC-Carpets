import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_analytics_entity.dart';

class AnalyticsSummaryCards extends StatelessWidget {
  final int totalOrders;
  final int totalItems;
  final double totalSqm;
  final AnalyticsMetric metric;

  const AnalyticsSummaryCards({
    super.key,
    required this.totalOrders,
    required this.totalItems,
    this.totalSqm = 0,
    this.metric = AnalyticsMetric.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Jami buyurtmalar',
              value: totalOrders.toString(),
              icon: Icons.receipt_long_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: metric == AnalyticsMetric.quantity
                ? _SummaryCard(
                    label: 'Jami mahsulotlar',
                    value: totalItems.toString(),
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.accent,
                  )
                : _SummaryCard(
                    label: 'Jami maydon',
                    value: metric.format(totalSqm),
                    icon: Icons.square_foot_rounded,
                    color: AppColors.accent,
                  ),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
