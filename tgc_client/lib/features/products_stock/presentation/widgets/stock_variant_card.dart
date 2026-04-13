import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/features/products_stock/domain/entities/stock_variant_entity.dart';

class StockVariantCard extends StatelessWidget {
  const StockVariantCard({super.key, required this.variant});

  final StockVariantEntity variant;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppThumbnail(imageUrl: variant.imageUrl, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              variant.productName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '#${variant.id}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StockChip(
                            label: 'Ombor',
                            value: variant.quantityWarehouse,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          _StockChip(
                            label: 'Band',
                            value: variant.quantityReserved,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          _StockChip(
                            label: 'Bosh',
                            value: variant.quantityWarehouse -
                                variant.quantityReserved,
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.start,
              children: [
                AppBadge(
                  label: variant.colorName.toUpperCase(),
                  color: Colors.black87,
                ),
                if (variant.typeName != null)
                  AppBadge(label: variant.typeName!, color: Colors.black87),
                if (variant.qualityName != null)
                  AppBadge(
                      label: variant.qualityName!,
                      color: AppColors.primaryLight),
                if (variant.size != null)
                  AppBadge(
                      label: variant.size!, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
