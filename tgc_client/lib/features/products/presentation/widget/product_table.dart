import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/widgets/app_badge.dart';
import 'package:tgc_client/core/widgets/app_data_table.dart';
import 'package:tgc_client/core/widgets/app_status_chip.dart';
import 'package:tgc_client/core/widgets/app_thumbnail.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';

/// Product-specific data table that wraps the generic [AppDataTable].
class ProductDataTable extends StatelessWidget {
  const ProductDataTable({
    super.key,
    required this.products,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onEdit,
    required this.onArchiveToggle,
    required this.onDelete,
    required this.onAddColor,
    this.pendingProductId,
  });

  final List<ProductEntity> products;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity) onArchiveToggle;
  final void Function(ProductEntity) onDelete;
  final void Function(ProductEntity) onAddColor;
  final int? pendingProductId;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 48),
    AppTableColumn(label: 'Nomi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Sifat', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Turi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Ranglar', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holat', flex: 1, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Amallar', fixedWidth: 120),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<ProductEntity>(
      items: products,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, product, colIndex) =>
          _buildCell(context, product, colIndex),
    );
  }

  Widget _buildCell(BuildContext context, ProductEntity product, int colIndex) {
    final isPending = pendingProductId == product.id;
    switch (colIndex) {
      case 0: // ID
        return Text(
          product.id.toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        );
      case 1: // name
        return Text(
          product.name,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        );
      case 2: // quality
        return product.productQuality != null
            ? AppBadge(
                label: product.productQuality!.qualityName,
                color: AppColors.primaryLight)
            : const Text('—');
      case 3: // type
        return product.productType != null
            ? AppBadge(label: product.productType!.type, color: Colors.black87)
            : const Text('—');
      case 4: // colors strip + add button
        return _ColorsCell(
          product: product,
          onAddColor: () => onAddColor(product),
        );
      case 5: // status
        return AppStatusChip(
          label: product.isActive ? 'Faol' : 'Arxivlangan',
          color: product.isActive ? AppColors.success : AppColors.textSecondary,
        );
      case 6: // actions
        if (isPending) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: AppColors.primary,
                size: 22,
                strokeWidth: 1.5,
              ),
              tooltip: 'Tahrirlash',
              color: AppColors.primary,
              onTap: () => onEdit(product),
            ),
            _ActionButton(
              icon: product.isActive
                  ? HugeIcon(
                      icon: HugeIcons.strokeRoundedArchive03,
                      color: AppColors.warning,
                      size: 22,
                      strokeWidth: 1.5,
                    )
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedUnarchive03,
                      color: AppColors.success,
                      size: 22,
                      strokeWidth: 1.5,
                    ),
              tooltip: product.isActive ? 'Arxivlash' : 'Faollashtirish',
              color: AppColors.textSecondary,
              onTap: () => onArchiveToggle(product),
            ),
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                size: 22,
                strokeWidth: 1.5,
              ),
              tooltip: 'O\'chirish',
              color: AppColors.error,
              onTap: () => onDelete(product),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Displays a horizontal strip of color thumbnails with an add-color button.
class _ColorsCell extends StatelessWidget {
  const _ColorsCell({required this.product, required this.onAddColor});

  final ProductEntity product;
  final VoidCallback onAddColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...product.productColors.take(5).map(
              (pc) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: pc.colorName,
                  child: AppThumbnail(imageUrl: pc.imageUrl, size: 32),
                ),
              ),
            ),
        if (product.productColors.length > 5)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: Text(
                  '+${product.productColors.length - 5}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            ),
          ),
        Tooltip(
          message: 'Rang qo\'shish',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onAddColor,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: icon,
        ),
      ),
    );
  }
}
