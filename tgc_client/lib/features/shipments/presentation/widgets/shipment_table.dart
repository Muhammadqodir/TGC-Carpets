import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';

import '../../domain/entities/shipment_entity.dart';

/// Shipments data table that wraps the generic [AppDataTable].
class ShipmentTable extends StatelessWidget {
  const ShipmentTable({
    super.key,
    required this.shipments,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<ShipmentEntity> shipments;
  final bool isLoadingMore;
  final ScrollController scrollController;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 68, alignment: Alignment.center),
    AppTableColumn(label: 'Sana', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mijoz / Hudud', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hajm', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Jami (m²)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(label: 'Jami (\$)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(label: 'Izoh', flex: 3, alignment: Alignment.centerLeft),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<ShipmentEntity>(
      items: shipments,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, shipment, colIndex) =>
          _buildCell(context, shipment, colIndex),
    );
  }

  Widget _buildCell(
      BuildContext context, ShipmentEntity shipment, int colIndex) {
    switch (colIndex) {
      case 0: // ID
        return Text(
          '${shipment.id}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );

      case 1: // Date
        return Text(
          _formatDateTime(shipment.shipmentDatetime),
          style: Theme.of(context).textTheme.bodyMedium,
        );

      case 2: // Client / Region
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shipment.clientShopName ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (shipment.clientRegion != null &&
                shipment.clientRegion!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                shipment.clientRegion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );

      case 3: // Volume (pieces + m², item count)
        return _VolumeCell(shipment: shipment);

      case 4: // Total m²
        final m2 = shipment.totalM2;
        return Text(
          m2 > 0 ? m2.toStringAsFixed(1) : '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.right,
        );

      case 5: // Total $
        return Text(
          '\$${shipment.grandTotal.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
          textAlign: TextAlign.right,
        );

      case 6: // Notes
        return shipment.notes != null && shipment.notes!.isNotEmpty
            ? Text(
                shipment.notes!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                '—',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDateTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$d.$mo.${date.year} $h:$m';
  }
}

// ---------------------------------------------------------------------------

class _VolumeCell extends StatelessWidget {
  final ShipmentEntity shipment;

  const _VolumeCell({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final totalPieces = shipment.totalPieces;
    final totalM2     = shipment.totalM2;

    final parts = <String>[];
    if (totalPieces > 0) parts.add('$totalPieces dona');
    if (totalM2 > 0) parts.add('${totalM2.toStringAsFixed(1)} m²');

    if (parts.isEmpty) {
      return Text(
        '—',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.join(' • '),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          '${shipment.items.length} mahsulot',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
