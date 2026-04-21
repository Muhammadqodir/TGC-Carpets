import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_badge.dart';
import '../../domain/entities/raw_material_entity.dart';

/// Card used in the raw-materials list (mobile).
class RawMaterialCard extends StatelessWidget {
  final RawMaterialEntity material;
  final VoidCallback? onTap;

  const RawMaterialCard({super.key, required this.material, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            material.name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppBadge(
                          label: material.type,
                          color: AppColors.primaryLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Qoldiq: ${_formatQty(material.stockQuantity)} ${_unitLabel(material.unit)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: material.stockQuantity > 0
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

  String _unitLabel(String unit) => switch (unit) {
        'sqm'   => 'm²',
        'kg'    => 'kg',
        'piece' => 'dona',
        _       => unit,
      };
}
