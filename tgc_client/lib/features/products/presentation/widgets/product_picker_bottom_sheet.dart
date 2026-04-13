import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/search_picker_bottom_sheet.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../domain/entities/product_color_entity.dart';
import '../../domain/entities/product_entity.dart';

/// Holds the product and the exact colour the user selected.
class ProductPickerResult {
  final ProductEntity product;
  final ProductColorEntity? color;

  const ProductPickerResult({required this.product, this.color});
}

/// Two-step picker: first choose a product, then choose a colour.
///
/// Returns [ProductPickerResult] or null if the user dismisses either step.
class ProductPickerBottomSheet {
  ProductPickerBottomSheet._();

  static Future<ProductPickerResult?> show(BuildContext context) async {
    // ── Step 1: search & pick product ───────────────────────────────────────
    final product = await SearchPickerBottomSheet.show<ProductEntity>(
      context,
      title: 'Mahsulot tanlash',
      searchHint: 'Nom yoki tur...',
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

    if (product == null) return null;

    // ── Step 2: pick colour ──────────────────────────────────────────────────
    if (product.productColors.isEmpty) {
      return ProductPickerResult(product: product, color: null);
    }

    if (product.productColors.length == 1) {
      return ProductPickerResult(
        product: product,
        color: product.productColors.first,
      );
    }

    // ignore: use_build_context_synchronously
    final color = await _ColorPickerSheet.show(context, product);
    if (color == null) return null;

    return ProductPickerResult(product: product, color: color);
  }
}

// ── Colour picker sheet (step 2) ─────────────────────────────────────────────

class _ColorPickerSheet extends StatelessWidget {
  final ProductEntity product;

  const _ColorPickerSheet({required this.product});

  static Future<ProductColorEntity?> show(
    BuildContext context,
    ProductEntity product,
  ) {
    return showModalBottomSheet<ProductColorEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ColorPickerSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Rang tanlang',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          ...product.productColors.map((pc) => _ColorTile(color: pc)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final ProductColorEntity color;

  const _ColorTile({required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(color),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: color.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: color.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                color.colorName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.palette_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
      );
}

class _ProductPickerTile extends StatelessWidget {
  final ProductEntity product;

  const _ProductPickerTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final firstImageUrl = product.productColors
        .where((pc) => pc.imageUrl != null)
        .map((pc) => pc.imageUrl)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Product image / placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: firstImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: firstImageUrl,
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
                    ...product.productColors.take(3).map(
                          (pc) => _chip(pc.colorName, AppColors.accent),
                        ),
                  ],
                ),
              ],
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
