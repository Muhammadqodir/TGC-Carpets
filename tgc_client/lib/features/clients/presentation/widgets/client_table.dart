import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';

/// Client-specific data table that wraps the generic [AppDataTable].
/// Adapts between desktop (7 columns) and mobile (3 columns) layouts.
class ClientDataTable extends StatelessWidget {
  const ClientDataTable({
    super.key,
    required this.clients,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
    this.pendingClientId,
  });

  final List<ClientEntity> clients;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ClientEntity) onEdit;
  final void Function(ClientEntity) onDelete;
  final int? pendingClientId;

  static const _desktopColumns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 52),
    AppTableColumn(label: 'Do\'kon', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Kontakt', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Telefon', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Viloyat', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Manzil', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Amallar', fixedWidth: 88),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(label: 'Do\'kon / Viloyat', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Kontakt / Telefon', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Amallar', fixedWidth: 88),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;
        return AppDataTable<ClientEntity>(
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

  Widget _buildDesktopCell(BuildContext context, ClientEntity client, int colIndex) {
    final isPending = pendingClientId == client.id;
    switch (colIndex) {
      case 0: // id
        return Text(
          client.id.toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        );
      case 1: // shop name
        return Text(
          client.shopName,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        );
      case 2: // contact name
        return Text(
          client.contactName ?? '—',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        );
      case 3: // phone
        return Text(
          client.phone ?? '—',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        );
      case 4: // region
        return AppBadge(label: client.region, color: AppColors.accent);
      case 5: // address
        return Text(
          client.address ?? '—',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
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
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'Tahrirlash',
              onTap: () => onEdit(client),
            ),
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'O\'chirish',
              onTap: () => onDelete(client),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMobileCell(BuildContext context, ClientEntity client, int colIndex) {
    final isPending = pendingClientId == client.id;
    switch (colIndex) {
      case 0: // shop / region
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              client.shopName,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            AppBadge(label: client.region, color: AppColors.accent),
          ],
        );
      case 1: // contact / phone
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              client.contactName ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              client.phone ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontFamily: 'monospace', color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        );
      case 2: // actions
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
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'Tahrirlash',
              onTap: () => onEdit(client),
            ),
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'O\'chirish',
              onTap: () => onDelete(client),
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
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
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
