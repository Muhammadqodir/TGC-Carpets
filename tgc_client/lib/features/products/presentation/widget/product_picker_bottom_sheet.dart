import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/search_picker_bottom_sheet.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../domain/entities/product_entity.dart';

/// Convenience wrapper that opens a searchable product picker.
///
/// Returns the selected [ProductEntity] or null if dismissed.
class ProductPickerBottomSheet {
  ProductPickerBottomSheet._();

  static Future<ProductEntity?> show(BuildContext context) {
    return SearchPickerBottomSheet.show<ProductEntity>(
      context,
      title: 'Mahsulot tanlash',
      searchHint: 'Nom, rang yoki SKU...',
      onSearch: (query) async {
        final datasource = sl<ProductRemoteDataSource>();
        final result = await datasource.getProducts(
          search: query.isEmpty ? null : query,
          status: 'active',
          perPage: 30,
        );
        return result.data;
      },
      itemBuilder: (context, product) => _ProductPickerTile(product: product),
      emptyText: 'Mahsulot topilmadi.',
      errorText: 'Mahsulotlarni yuklashda xatolik.',
    );
  }
}

class _ProductPickerTile extends StatelessWidget {
  final ProductEntity product;

  const _ProductPickerTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Product image / placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: 44,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(4),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (product.productType != null)
                      _chip(product.productType!.type, AppColors.textSecondary),
                    if (product.productQuality != null)
                      _chip(product.productQuality!.qualityName,
                          AppColors.primaryLight),
                    _chip(product.color, AppColors.accent),
                  ],
                ),
                if (product.skuCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      product.skuCode!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          // Stock badge
          if (product.stock != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    (product.stock! > 0 ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${product.stock}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: product.stock! > 0
                          ? AppColors.success
                          : AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
      );
}
