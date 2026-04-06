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
    this.pendingProductId,
  });

  final List<ProductEntity> products;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity) onArchiveToggle;
  final void Function(ProductEntity) onDelete;
  final int? pendingProductId;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 48),
    AppTableColumn(label: 'Rasm', fixedWidth: 64),
    AppTableColumn(label: 'Nomi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'SKU', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Turi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Sifat', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Rang', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Omborda', flex: 1, alignment: Alignment.centerLeft),
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
      case 0: // index
        return Text(
          product.id.toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        );
      case 1: // thumbnail
        return AppThumbnail(imageUrl: product.imageUrl, size: 40);
      case 2: // name
        return Text(
          product.name,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        );
      case 3: // sku
        return Text(
          product.skuCode ?? '—',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
              ),
          overflow: TextOverflow.ellipsis,
        );
      case 4: // type
        return product.productType != null
            ? AppBadge(label: product.productType!.type, color: Colors.black87)
            : const Text('—');
      case 5: // quality
        return product.productQuality != null
            ? AppBadge(
                label: product.productQuality!.qualityName,
                color: AppColors.primaryLight)
            : const Text('—');
      case 6: // color
        return AppBadge(label: product.color, color: AppColors.accent);
      case 7: // stock
        final stock = product.stock;
        return Text(
          stock != null ? '${stock > 0 ? stock : 'Yoq'}' : '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: stock != null
                    ? (stock > 0 ? AppColors.success : AppColors.error)
                    : AppColors.textSecondary,
              ),
        );
      case 8: // status
        return AppStatusChip(
          label: product.isActive ? 'Faol' : 'Arxivlangan',
          color: product.isActive ? AppColors.success : AppColors.textSecondary,
        );
      case 9: // actions
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
