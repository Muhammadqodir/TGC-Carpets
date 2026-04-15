import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

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
    AppTableColumn(label: 'ID', fixedWidth: 68, alignment: Alignment.center),
    AppTableColumn(label: 'Sana', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holati', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Xodim', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mijoz', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mahsulotlar', flex: 1, alignment: Alignment.center),
    AppTableColumn(label: 'Jami dona', flex: 1, alignment: Alignment.center),
    AppTableColumn(label: 'Jami m²', flex: 1, alignment: Alignment.center),
    AppTableColumn(label: 'Ishlab chiqarish', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Omborda', flex: 1, alignment: Alignment.center),
    AppTableColumn(
        label: 'Amallar', fixedWidth: 100, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<OrderEntity>(
      items: orders,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, order, colIndex) =>
          _buildCell(context, order, colIndex),
    );
  }

  Widget _buildCell(BuildContext context, OrderEntity order, int colIndex) {
    switch (colIndex) {
      case 0:
        return Text(
          '${order.id}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );

      case 1:
        return Text(
          _formatDate(order.orderDate),
          style: Theme.of(context).textTheme.bodyMedium,
        );

      case 2:
        return _StatusChip(status: order.status);

      case 3:
        return Row(
          children: [
            const Icon(Icons.person_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                order.userName,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case 4:
        return order.clientShopName != null
            ? Row(
                children: [
                  const Icon(Icons.store_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.clientShopName! +
                          (order.clientRegion != null
                              ? ' / ${order.clientRegion!}'
                              : ''),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(
                '—',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              );

      case 5:
        return Center(
          child: Text(
            '${order.items.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

      case 6:
        return Center(
          child: Text(
            '${order.totalQuantity}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

      case 7:
        return Center(
          child: Text(
            '${order.totalSqm.toStringAsFixed(2)} m²',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

      case 8:
        return _ProductionProgressCell(order: order);

      case 9:
        return Center(
          child: Text(
            '${order.totalWarehouseReceivedQuantity}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

      case 10:
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

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _ProductionProgressCell extends StatelessWidget {
  final OrderEntity order;

  const _ProductionProgressCell({required this.order});

  @override
  Widget build(BuildContext context) {
    final total    = order.totalQuantity;
    final planned  = order.totalPlannedQuantity;
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
        Text(
          '$planned / $total',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary, fontSize: 10),
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
      'pending'       => ('Kutilmoqda', AppColors.warning),
      'planned'       => ('Rejalashtirilgan', AppColors.primary),
      'on_production' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'done'          => ('Bajarildi', AppColors.success),
      'shipped'       => ('Yuborildi', AppColors.info),
      'canceled'      => ('Bekor qilindi', AppColors.error),
      _               => (status, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
