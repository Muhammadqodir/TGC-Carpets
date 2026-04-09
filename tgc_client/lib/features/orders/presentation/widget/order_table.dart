import 'package:flutter/material.dart';

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
  });

  final List<OrderEntity> orders;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(OrderEntity)? onDelete;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID',      fixedWidth: 68, alignment: Alignment.center),
    AppTableColumn(label: 'Sana',    flex: 2,        alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holati',  flex: 2,        alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Xodim',   flex: 2,        alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mijoz',   flex: 2,        alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mahsulotlar', flex: 1,   alignment: Alignment.center),
    AppTableColumn(label: '',        fixedWidth: 52,  alignment: Alignment.center),
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
            const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
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
                  const Icon(Icons.store_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.clientShopName!,
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
          child: onDelete != null
              ? IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  onPressed: () => onDelete!(order),
                )
              : const SizedBox.shrink(),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending'   => ('Kutilmoqda', AppColors.warning),
      'confirmed' => ('Tasdiqlangan', AppColors.primaryLight),
      'cancelled' => ('Bekor qilindi', AppColors.error),
      'delivered' => ('Yetkazildi', AppColors.success),
      _           => (status, AppColors.textSecondary),
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
