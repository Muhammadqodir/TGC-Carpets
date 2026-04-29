import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';

import '../../domain/entities/client_debit_entity.dart';

/// Adaptive table showing all clients with Debit / Credit / Balance summary columns.
/// Desktop: 7 columns. Mobile: 3 columns.
class DebitSummaryTable extends StatelessWidget {
  const DebitSummaryTable({
    super.key,
    required this.clients,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onViewDetails,
    required this.onAddPayment,
  });

  final List<ClientDebitEntity> clients;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ClientDebitEntity) onViewDetails;
  final void Function(ClientDebitEntity) onAddPayment;

  static const _desktopColumns = <AppTableColumn>[
    AppTableColumn(label: '#', fixedWidth: 52, alignment: Alignment.center),
    AppTableColumn(label: 'Do\'kon', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hudud', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Yuklama (\$)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(
        label: 'To\'lov (\$)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(
        label: 'Balans (\$)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(label: 'Amallar', fixedWidth: 100),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(
      label: 'Do\'kon',
      flex: 2,
      alignment: Alignment.centerLeft,
    ),
    AppTableColumn(
      label: 'Yuklama / To\'lov',
      flex: 2,
      alignment: Alignment.centerLeft,
    ),
    AppTableColumn(
      label: 'Balans',
      flex: 2,
      alignment: Alignment.centerRight,
    ),
    AppTableColumn(label: '', fixedWidth: 40),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;
        return AppDataTable<ClientDebitEntity>(
          items: clients,
          columns: isMobile ? _mobileColumns : _desktopColumns,
          scrollController: scrollController,
          isLoadingMore: isLoadingMore,
          cellBuilder: (context, client, colIndex) => isMobile
              ? _buildMobileCell(context, client, colIndex)
              : _buildDesktopCell(context, client, colIndex),
        );
      },
    );
  }

  Widget _buildDesktopCell(
    BuildContext context,
    ClientDebitEntity client,
    int colIndex,
  ) {
    final theme = Theme.of(context);

    switch (colIndex) {
      case 0: // ID
        return GestureDetector(
          onTap: () => onViewDetails(client),
          child: Text(
            '${client.id}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        );

      case 1: // Do'kon
        return GestureDetector(
          onTap: () => onViewDetails(client),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.shopName ?? '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (client.contactName != null)
                Text(
                  client.contactName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );

      case 2: // Mintaqa
        return Text(
          client.region ?? '—',
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

      case 3: // Yuklama
        return Text(
          '-${client.totalDebit.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        );

      case 4: // To'lov
        return Text(
          '+${client.totalCredit.toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        );

      case 5: // Balans
        final balance = client.balance;
        final isPositive = balance > 0;
        final balanceSign = balance > 0 ? '-' : (balance < 0 ? '+' : '');
        return Text(
          '$balanceSign${balance.abs().toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isPositive ? AppColors.error : AppColors.success,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.right,
        );

      case 6: // Amallar
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedView,
                strokeWidth: 2,
                size: 20,
              ),
              tooltip: 'Batafsil',
              color: AppColors.primary,
              onTap: () => onViewDetails(client),
            ),
            _ActionButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMoneyAdd02,
                strokeWidth: 2,
                size: 20,
              ),
              tooltip: "To'lov qo'shish",
              color: AppColors.success,
              onTap: () => onAddPayment(client),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMobileCell(
    BuildContext context,
    ClientDebitEntity client,
    int colIndex,
  ) {
    final theme = Theme.of(context);
    final balance = client.balance;
    final isPositive = balance > 0;

    switch (colIndex) {
      case 0: // Do'kon / Mintaqa
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              client.shopName ?? '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              client.region ?? '—',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

      case 1: // Yuklama / To'lov
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '-${client.totalDebit.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              '+${client.totalCredit.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
            ),
          ],
        );

      case 2:
        return Text(
          '${balance > 0 ? '-' : (balance < 0 ? '+' : '')}${balance.abs().toStringAsFixed(2)}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isPositive ? AppColors.error : AppColors.success,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
        );

      case 3: // Actions dropdown
        return PopupMenuButton<String>(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedMoreVertical,
          ),
          surfaceTintColor: AppColors.surface,
          color: AppColors.surface,
          onSelected: (value) {
            switch (value) {
              case 'view':
                onViewDetails(client);
                break;
              case 'payment':
                onAddPayment(client);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    color: AppColors.primary,
                    size: 18,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 8),
                  const Text('Batafsil'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'payment',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedMoneyAdd02,
                    color: AppColors.success,
                    size: 18,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 8),
                  const Text("To'lov qo'shish"),
                ],
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Action button
// ---------------------------------------------------------------------------

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
      child: IconButton(
        onPressed: onTap,
        icon: IconTheme(
          data: IconThemeData(color: color),
          child: icon,
        ),
      ),
    );
  }
}
