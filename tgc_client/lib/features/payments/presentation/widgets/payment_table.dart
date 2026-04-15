import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';

import '../../domain/entities/payment_entity.dart';

/// Payments data table that wraps the generic [AppDataTable].
class PaymentTable extends StatelessWidget {
  const PaymentTable({
    super.key,
    required this.payments,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onDelete,
  });

  final List<PaymentEntity> payments;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(PaymentEntity) onDelete;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 64, alignment: Alignment.center),
    AppTableColumn(label: 'Sana', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mijoz', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Buyurtma', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Miqdor (\$)', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Izoh', flex: 4, alignment: Alignment.centerLeft),
    AppTableColumn(label: '', fixedWidth: 48, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<PaymentEntity>(
      items: payments,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, payment, colIndex) =>
          _buildCell(context, payment, colIndex),
    );
  }

  Widget _buildCell(BuildContext context, PaymentEntity payment, int colIndex) {
    switch (colIndex) {
      case 0: // ID
        return Text(
          '${payment.id}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );

      case 1: // Date
        return Text(
          _formatDate(payment.createdAt),
          style: Theme.of(context).textTheme.bodyMedium,
        );

      case 2: // Client
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payment.clientShopName ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (payment.clientRegion != null &&
                payment.clientRegion!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                payment.clientRegion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );

      case 3: // Order
        return Text(
          payment.orderId != null ? '#${payment.orderId}' : '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: payment.orderId != null
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
          textAlign: TextAlign.left,
        );

      case 4: // Amount
        return Text(
          '\$${payment.amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
          textAlign: TextAlign.left,
        );

      case 5: // Notes
        return Text(
          payment.notes ?? '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: payment.notes != null ? null : AppColors.textSecondary,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case 6: // Delete action
        return IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedDelete01,
            size: 20,
          ),
          color: AppColors.error,
          tooltip: "O'chirish",
          onPressed: () => onDelete(payment),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
