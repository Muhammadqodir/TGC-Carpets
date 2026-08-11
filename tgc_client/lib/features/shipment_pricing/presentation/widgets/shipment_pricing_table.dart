import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_data_table.dart';
import '../../../../core/ui/widgets/typograpthy.dart';
import '../../../shipments/domain/entities/shipment_entity.dart';
import '../../domain/shipment_money.dart';

/// The pricing feature's own list of shipments.
///
/// Deliberately not the shipments table: that one is a warehouse view, full
/// of delivery notes, Excel exports and cancellation, and it carries no money
/// at all. This one answers a single question — which shipments still need a
/// price — so it shows what a shipment is worth and nothing that would change
/// what left the building.
class ShipmentPricingTable extends StatelessWidget {
  const ShipmentPricingTable({
    super.key,
    required this.shipments,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onTap,
  });

  final List<ShipmentEntity> shipments;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ShipmentEntity) onTap;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 68, alignment: Alignment.center),
    AppTableColumn(label: 'Sana', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Mijoz / Hudud', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hajm', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Jami (\$)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(label: '', fixedWidth: 56, alignment: Alignment.center),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(label: 'Yuk', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Jami (\$)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(label: '', fixedWidth: 48, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;

      return AppDataTable<ShipmentEntity>(
        items: shipments,
        columns: isMobile ? _mobileColumns : _columns,
        scrollController: scrollController,
        isLoadingMore: isLoadingMore,
        cellBuilder: (context, shipment, colIndex) => isMobile
            ? _buildMobileCell(context, shipment, colIndex)
            : _buildCell(context, shipment, colIndex),
      );
    });
  }

  Widget _buildMobileCell(
    BuildContext context,
    ShipmentEntity shipment,
    int colIndex,
  ) {
    switch (colIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyText(
              text: '#${shipment.id} · ${shipment.clientShopName ?? '—'}',
              fontWeight: FontWeight.w600,
            ),
            SubBodyText(
              text: '${_formatDate(shipment.shipmentDatetime)} · '
                  '${shipment.totalQuantity} dona',
            ),
            if (shipment.isCanceled) const _CanceledBadge(),
          ],
        );

      case 1:
        return _TotalCell(shipment: shipment);

      case 2:
        return _OpenButton(onPressed: () => onTap(shipment));

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCell(
    BuildContext context,
    ShipmentEntity shipment,
    int colIndex,
  ) {
    switch (colIndex) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${shipment.id}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    decoration:
                        shipment.isCanceled ? TextDecoration.lineThrough : null,
                  ),
            ),
            if (shipment.isCanceled) const _CanceledBadge(),
          ],
        );

      case 1:
        return Text(
          _formatDate(shipment.shipmentDatetime),
          style: Theme.of(context).textTheme.bodyMedium,
        );

      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyText(
              text: shipment.clientShopName ?? '—',
              fontWeight: FontWeight.w600,
            ),
            if (shipment.clientRegion != null &&
                shipment.clientRegion!.isNotEmpty)
              SubBodyText(text: shipment.clientRegion!),
          ],
        );

      case 3:
        final m2 = shipment.totalM2;
        return BodyText(
          text: '${shipment.totalQuantity} dona'
              '${m2 > 0 ? ' · ${m2.toStringAsFixed(1)} m²' : ''}',
        );

      case 4:
        return _TotalCell(shipment: shipment);

      case 5:
        return _OpenButton(onPressed: () => onTap(shipment));

      default:
        return const SizedBox.shrink();
    }
  }

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$d.$mo.${date.year}';
  }
}

/// A shipment leaves the warehouse unpriced, so 0.00 means "still waiting for
/// the office", not "free" — the whole point of this list is spotting those.
class _TotalCell extends StatelessWidget {
  final ShipmentEntity shipment;

  const _TotalCell({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final total = shipment.grandTotal;

    return Text(
      total > 0 ? '\$${total.toStringAsFixed(2)}' : 'Narxsiz',
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: total > 0 ? AppColors.success : AppColors.warning,
          ),
    );
  }
}

class _OpenButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _OpenButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Narxlarni kiritish',
      visualDensity: VisualDensity.compact,
      icon: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.primary,
        size: 26,
      ),
    );
  }
}

class _CanceledBadge extends StatelessWidget {
  const _CanceledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Bekor qilingan',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
