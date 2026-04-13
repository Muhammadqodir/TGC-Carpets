import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import '../../domain/entities/product_entity.dart';

class ProductItem extends StatelessWidget {
  final ProductEntity product;

  const ProductItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final firstImageUrl = product.productColors
        .where((pc) => pc.imageUrl != null)
        .map((pc) => pc.imageUrl)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            AppThumbnail(
              imageUrl: firstImageUrl,
              size: 50,
              borderRadius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                      ...product.productColors.take(3).map(
                            (pc) => AppBadge(
                              label: pc.colorName.toUpperCase(),
                              color: AppColors.accent,
                            ),
                          ),
                      if (product.productColors.length > 3)
                        AppBadge(
                          label: '+${product.productColors.length} rang',
                          color: AppColors.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AppBadge(
                    label: product.isActive ? 'Faol' : 'Arxivlangan',
                    color: product.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
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
