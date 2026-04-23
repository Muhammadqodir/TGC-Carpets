import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_data_table.dart';
import '../../domain/entities/order_entity.dart';

class OrderTable extends StatelessWidget {
  const OrderTable({
    super.key,
    required this.orders,
    required this.isLoadingMore,
    required this.scrollController,
    this.onDelete,
    this.onViewDetail,
    this.onEdit,
  });

  final List<OrderEntity> orders;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(OrderEntity)? onDelete;
  final void Function(OrderEntity)? onViewDetail;
  final void Function(OrderEntity)? onEdit;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 68, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Sana', fixedWidth: 90, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Holati', fixedWidth: 70, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mijoz', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hajmi', flex: 1, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Ishlab chiqarish', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Amallar', fixedWidth: 100, alignment: Alignment.center),
  ];

  static const _columnsMobile = <AppTableColumn>[
    AppTableColumn(label: 'Buyurtma', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holati', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: '', fixedWidth: 40, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      final columns = isDesktop ? _columns : _columnsMobile;

      return AppDataTable<OrderEntity>(
        items: orders,
        columns: columns,
        scrollController: scrollController,
        isLoadingMore: isLoadingMore,
        cellBuilder: (context, order, colIndex) =>
            _buildCell(context, order, colIndex, isDesktop),
      );
    });
  }

  Widget _buildCell(
      BuildContext context, OrderEntity order, int colIndex, bool isDesktop) {
    if (!isDesktop) {
      return _buildMobileCell(context, order, colIndex);
    }
    return _buildDesktopCell(context, order, colIndex);
  }

  Widget _buildDesktopCell(
      BuildContext context, OrderEntity order, int colIndex) {
    switch (colIndex) {
      case 0:
        return BodyText(text: '#${order.id}');

      case 1:
        return BodyText(text: _formatDate(order.orderDate));

      case 2:
        return _StatusChip(status: order.status);

      case 3:
        return BodyText(
          text: "${order.clientShopName ?? '—'} / ${order.clientRegion ?? '—'}",
        );

      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyText(text: '${order.totalPlannedQuantity} ta'),
            BodyText(text: '${order.totalSqm.toStringAsFixed(2)} m²'),
          ],
        );

      case 5:
        return _ProductionProgressCell(order: order);

      case 6:
        return _ActionsCell(
            order: order,
            onViewDetail: onViewDetail,
            onEdit: onEdit,
            onDelete: onDelete);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMobileCell(
    BuildContext context,
    OrderEntity order,
    int colIndex,
  ) {
    switch (colIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            BodyText(
              text: "#${order.id} ${_formatDate(order.orderDate)}",
              fontWeight: FontWeight.bold,
            ),
            BodyText(
                text:
                    '${order.clientShopName ?? '—'} / ${order.clientRegion ?? '—'}'),
          ],
        );

      case 1:
        return Column(
          spacing: 4,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusChip(status: order.status),
            _ProductionProgressCell(order: order),
          ],
        );

      case 2:
        return _ActionsCell(
          order: order,
          onViewDetail: onViewDetail,
          onEdit: onEdit,
          onDelete: onDelete,
          compact: true,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _ActionsCell extends StatelessWidget {
  const _ActionsCell({
    required this.order,
    this.onViewDetail,
    this.onEdit,
    this.onDelete,
    this.compact = false,
  });

  final OrderEntity order;
  final void Function(OrderEntity)? onViewDetail;
  final void Function(OrderEntity)? onEdit;
  final void Function(OrderEntity)? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return PopupMenuButton<String>(
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical),
        surfaceTintColor: AppColors.surface,
        color: AppColors.surface,
        onSelected: (value) {
          switch (value) {
            case 'view':
              onViewDetail?.call(order);
              break;
            case 'edit':
              onEdit?.call(order);
              break;
            case 'delete':
              onDelete?.call(order);
              break;
          }
        },
        itemBuilder: (context) => [
          if (onViewDetail != null)
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    color: AppColors.primaryLight,
                    size: 18,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 8),
                  const Text('Tafsilotlar'),
                ],
              ),
            ),
          if (order.status == 'pending' && onEdit != null)
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit02,
                    color: AppColors.warning,
                    size: 18,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 8),
                  const Text('Tahrirlash'),
                ],
              ),
            ),
          if (onDelete != null)
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedRemove01,
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
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onViewDetail != null)
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedView,
                color: AppColors.primaryLight,
              ),
              onPressed: () => onViewDetail!(order),
              tooltip: 'Tafsilotlar',
            ),
          if (order.status == 'pending' && onEdit != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: AppColors.warning,
              ),
              onPressed: () => onEdit!(order),
              tooltip: 'Tahrirlash',
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRemove01,
                color: AppColors.error,
              ),
              onPressed: () => onDelete!(order),
              tooltip: 'O\'chirish',
            ),
          ],
        ],
      ),
    );
  }
}

class _ProductionProgressCell extends StatelessWidget {
  final OrderEntity order;

  const _ProductionProgressCell({required this.order});

  @override
  Widget build(BuildContext context) {
    final total = order.totalQuantity;
    final produced = order.totalProducedQuantity;
    final progress = order.productionProgress;

    if (total == 0) {
      return Text('—',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary));
    }

    final color = progress >= 1.0
        ? AppColors.success
        : progress > 0
            ? AppColors.primaryLight
            : AppColors.textSecondary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.textSecondary.withAlpha(40),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 3),
        SubBodyText(
          text:
              '$produced / $total ta tayor | ${order.totalWarehouseReceivedQuantity} ta omborda',
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Kutilmoqda', AppColors.warning),
      'planned' => ('Rejalashtirilgan', AppColors.primary),
      'on_production' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'done' => ('Bajarildi', AppColors.success),
      'shipped' => ('Yuborildi', AppColors.info),
      'canceled' => ('Bekor qilindi', AppColors.error),
      _ => (status, AppColors.textSecondary),
    };

    return AppBadge(
      label: label,
      color: color,
    );
  }
}
