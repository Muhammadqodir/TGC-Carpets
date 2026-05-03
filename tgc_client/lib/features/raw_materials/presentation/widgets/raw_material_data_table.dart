import 'package:flutter/material.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/features/raw_materials/domain/entities/raw_material_entity.dart';

/// Raw materials data table with adaptive layout (desktop 5 columns, mobile 3 columns).
class RawMaterialDataTable extends StatelessWidget {
  const RawMaterialDataTable({
    super.key,
    required this.materials,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<RawMaterialEntity> materials;
  final bool isLoadingMore;
  final ScrollController scrollController;

  static const _desktopColumns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 56),
    AppTableColumn(label: 'Nomi', flex: 4, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Turi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Qoldiq', flex: 2),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(label: 'Nomi / Turi', flex: 4, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Qoldiq', flex: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;
        return AppDataTable<RawMaterialEntity>(
          items: materials,
          columns: isMobile ? _mobileColumns : _desktopColumns,
          scrollController: scrollController,
          isLoadingMore: isLoadingMore,
          cellBuilder: (context, material, colIndex) => isMobile
              ? _buildMobileCell(context, material, colIndex)
              : _buildDesktopCell(context, material, colIndex),
        );
      },
    );
  }

  Widget _buildDesktopCell(
      BuildContext context, RawMaterialEntity material, int colIndex) {
    switch (colIndex) {
      case 0: // ID
        return Text(
          material.id.toString(),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );

      case 1: // Nomi
        return Text(
          material.name,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        );

      case 2: // Turi
        return AppBadge(label: material.type, color: AppColors.primaryLight);

      case 3: // Qoldiq
        return _StockCell(value: material.stockQuantity, unit: material.unit);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMobileCell(
      BuildContext context, RawMaterialEntity material, int colIndex) {
    switch (colIndex) {
      case 0: // Nomi / Turi
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              material.name,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            AppBadge(
              label: material.type,
              color: AppColors.primaryLight,
            ),
          ],
        );

      case 1: // Qoldiq
        return _StockCell(value: material.stockQuantity, unit: material.unit);

      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------

class _StockCell extends StatelessWidget {
  const _StockCell({required this.value, required this.unit});

  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final isPositive = value > 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final formatted = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    final unitLabel = _unitLabel(unit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$formatted $unitLabel',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

String _unitLabel(String unit) => switch (unit) {
      'sqm' => 'm²',
      'kg' => 'kg',
      'meter' => 'm',
      'piece' => 'dona',
      _ => unit,
    };
