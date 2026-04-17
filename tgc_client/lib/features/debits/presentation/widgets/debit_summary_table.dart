import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';

import '../../domain/entities/client_debit_entity.dart';

/// Table showing all clients with Debit / Credit / Balance summary columns.
class DebitSummaryTable extends StatelessWidget {
  const DebitSummaryTable({
    super.key,
    required this.clients,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onRowTap,
  });

  final List<ClientDebitEntity> clients;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ClientDebitEntity) onRowTap;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: '#',         fixedWidth: 52,  alignment: Alignment.center),
    AppTableColumn(label: 'Do\'kon',   flex: 3,         alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mintaqa',   flex: 2,         alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Debit (\$)', flex: 2,        alignment: Alignment.centerRight),
    AppTableColumn(label: 'Kredit (\$)', flex: 2,       alignment: Alignment.centerRight),
    AppTableColumn(label: 'Balans (\$)', flex: 2,       alignment: Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<ClientDebitEntity>(
      items:            clients,
      columns:          _columns,
      scrollController: scrollController,
      isLoadingMore:    isLoadingMore,
      cellBuilder:      (context, client, colIndex) =>
          _buildCell(context, client, colIndex),
    );
  }

  Widget _buildCell(
    BuildContext context,
    ClientDebitEntity client,
    int colIndex,
  ) {
    final theme = Theme.of(context);

    switch (colIndex) {
      case 0:
        return GestureDetector(
          onTap: () => onRowTap(client),
          child: Text(
            '${client.id}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        );

      case 1:
        return GestureDetector(
          onTap: () => onRowTap(client),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.shopName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                client.contactName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );

      case 2:
        return Text(
          client.region,
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

      case 3: // Debit
        return Text(
          client.totalDebit.toStringAsFixed(2),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        );

      case 4: // Credit
        return Text(
          client.totalCredit.toStringAsFixed(2),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        );

      case 5: // Balance
        final isPositive = client.balance >= 0;
        return Text(
          client.balance.toStringAsFixed(2),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isPositive ? AppColors.error : AppColors.success,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.right,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
