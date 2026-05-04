import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_color_entity.dart';

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
    required this.onEditColor,
    required this.onRemoveColor,
    this.pendingProductId,
  });

  final List<ProductEntity> products;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ProductEntity) onEdit;
  final void Function(ProductEntity) onArchiveToggle;
  final void Function(ProductEntity) onDelete;
  final void Function(ProductEntity) onAddColor;
  final void Function(ProductEntity, ProductColorEntity) onEditColor;
  final void Function(ProductEntity, ProductColorEntity) onRemoveColor;
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

  static const _columnsMobile = <AppTableColumn>[
    AppTableColumn(label: 'Mahsulot', flex: 1, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Ranglar', flex: 1, alignment: Alignment.centerLeft),
    AppTableColumn(label: '', fixedWidth: 40),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      final columns = isDesktop ? _columns : _columnsMobile;

      return AppDataTable<ProductEntity>(
        items: products,
        columns: columns,
        scrollController: scrollController,
        isLoadingMore: isLoadingMore,
        cellBuilder: (context, product, colIndex) => _buildCell(
          context: context,
          product: product,
          colIndex: colIndex,
          isDesktop: isDesktop,
        ),
      );
    });
  }

  Widget _buildCell({
    required BuildContext context,
    required ProductEntity product,
    required int colIndex,
    required bool isDesktop,
  }) {
    final isPending = pendingProductId == product.id;
    switch (colIndex) {
      case 0: // ID
        if (isDesktop) {
          return SubBodyText(text: product.id.toString());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: 4,
              children: [
                BodyText(
                  text: product.name,
                  fontWeight: FontWeight.bold,
                ),
                if (!product.isActive)
                  AppBadge(
                    label: 'Arxivlangan',
                    textColor: Colors.white,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            BodyText(
              text:
                  '${product.productType?.type ?? '-'} | ${product.productQuality?.qualityName ?? '-'}',
            ),
          ],
        );
      case 1: // name or actions
        if (isDesktop) {
          return BodyText(text: product.name);
        }
        return _ColorsCell(
          product: product,
          onAddColor: () => onAddColor(product),
          onEditColor: (color) => onEditColor(product, color),
          onRemoveColor: (color) => onRemoveColor(product, color),
        );
      case 2: // quality
        if (isDesktop) {
          return AppBadge(
            label: product.productQuality?.qualityName ?? '-',
            color: AppColors.primaryLight,
          );
        }
        return buildActions(product, isPending, isDesktop);
      case 3: // type
        return AppBadge(
          label: product.productType?.type ?? '-',
          color: Colors.black87,
        );
      case 4: // colors strip + add button
        return _ColorsCell(
          product: product,
          onAddColor: () => onAddColor(product),
          onEditColor: (color) => onEditColor(product, color),
          onRemoveColor: (color) => onRemoveColor(product, color),
        );
      case 5: // status
        return AppBadge(
          label: product.isActive ? 'Faol' : 'Arxivlangan',
          color: product.isActive ? AppColors.success : AppColors.textSecondary,
        );
      case 6: // actions
        return buildActions(product, isPending, isDesktop);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget buildActions(ProductEntity product, bool isPending, bool isDesktop) {
    if (isPending) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!isDesktop) {
      return PopupMenuButton<String>(
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedMoreVertical,
        ),
        surfaceTintColor: AppColors.surface,
        color: AppColors.surface,
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit(product);
              break;
            case 'archive':
              onArchiveToggle(product);
              break;
            case 'delete':
              onDelete(product);
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedEdit02,
                  color: AppColors.primary,
                  size: 18,
                  strokeWidth: 2,
                ),
                const SizedBox(width: 8),
                const Text('Tahrirlash'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'archive',
            child: Row(
              children: [
                HugeIcon(
                  icon: product.isActive
                      ? HugeIcons.strokeRoundedArchive03
                      : HugeIcons.strokeRoundedUnarchive03,
                  color: AppColors.warning,
                  strokeWidth: 2,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(product.isActive ? 'Arxivlash' : 'Faollashtirish'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedDelete02,
                  color: AppColors.error,
                  strokeWidth: 2,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text('O\'chirish'),
              ],
            ),
          ),
        ],
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
  }
}

/// Displays a horizontal strip of color thumbnails with an add-color button.
class _ColorsCell extends StatelessWidget {
  const _ColorsCell({
    required this.product,
    required this.onAddColor,
    required this.onEditColor,
    required this.onRemoveColor,
  });

  final ProductEntity product;
  final VoidCallback onAddColor;
  final void Function(ProductColorEntity) onEditColor;
  final void Function(ProductColorEntity) onRemoveColor;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...product.productColors.take(5).map(
                (pc) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _ColorThumbnail(
                    color: pc,
                    onEdit: () => onEditColor(pc),
                    onRemove: () => onRemoveColor(pc),
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
      ),
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

class _ColorThumbnail extends StatelessWidget {
  const _ColorThumbnail({
    required this.color,
    required this.onEdit,
    required this.onRemove,
  });

  final ProductColorEntity color;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay?.size.width ?? position.dx,
        overlay?.size.height ?? position.dy,
      ),
      surfaceTintColor: AppColors.surface,
      color: AppColors.surface,
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: AppColors.primary,
                size: 18,
                strokeWidth: 2,
              ),
              const SizedBox(width: 8),
              const Text('Tahrirlash'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                size: 18,
                strokeWidth: 2,
              ),
              const SizedBox(width: 8),
              const Text('O\'chirish'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        onEdit();
      } else if (value == 'remove') {
        onRemove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
      child: Tooltip(
        message: color.colorName,
        child: AppThumbnail(imageUrl: color.imageUrl, size: 32),
      ),
    );
  }
}
