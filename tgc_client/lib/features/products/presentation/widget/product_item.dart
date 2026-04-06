import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/widgets/app_badge.dart';
import 'package:tgc_client/core/widgets/app_status_chip.dart';
import 'package:tgc_client/core/widgets/app_thumbnail.dart';
import '../../domain/entities/product_entity.dart';

class ProductItem extends StatelessWidget {
  final ProductEntity product;

  const ProductItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AppThumbnail(
              imageUrl: product.imageUrl,
              size: 50,
              borderRadius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.stock != null)
                        AppBadge(
                          label: '${product.stock} ta',
                          color: product.stock! > 0
                              ? AppColors.success
                              : AppColors.error,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (product.productType != null)
                        AppBadge(
                          label: product.productType!.type,
                          color: Colors.black87,
                        ),
                      if (product.productQuality != null)
                        AppBadge(
                          label: product.productQuality!.qualityName,
                          color: AppColors.primaryLight,
                        ),
                      AppBadge(
                          label: product.color, color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.skuCode ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AppStatusChip(
                        label: product.isActive ? 'Faol' : 'Arxivlangan',
                        color: product.isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
