import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/shipment_entity.dart';

/// Mobile card for a single [ShipmentEntity].
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({super.key, required this.shipment});

  final ShipmentEntity shipment;

  @override
  Widget build(BuildContext context) {
    final totalM2   = shipment.totalM2;
    final totalQty  = shipment.totalQuantity;
    final itemCount = shipment.items.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: ID + date ─────────────────────────────────────────
            Row(
              children: [
                Text(
                  '#${shipment.id}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const Spacer(),
                Text(
                  _formatDate(shipment.shipmentDatetime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Client ────────────────────────────────────────────────────
            if (shipment.clientShopName != null) ...[
              Row(
                children: [
                  const Icon(Icons.store_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        shipment.clientShopName!,
                        if (shipment.clientRegion != null &&
                            shipment.clientRegion!.isNotEmpty)
                          shipment.clientRegion!,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),

            // ── Volume row ────────────────────────────────────────────────
            Row(
              children: [
                _InfoChip(
                  icon: Icons.inventory_2_outlined,
                  label: '$itemCount xil • $totalQty dona',
                ),
                if (totalM2 > 0) ...[
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.square_foot,
                    label: '${totalM2.toStringAsFixed(2)} m²',
                    color: AppColors.primaryLight,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // ── Grand total ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (shipment.notes != null && shipment.notes!.isNotEmpty)
                  Expanded(
                    child: Text(
                      shipment.notes!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                Text(
                  '\$${shipment.grandTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d.$mo.${dt.year} $h:$m';
  }
}

// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
