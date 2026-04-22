import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/features/raw_materials/domain/entities/raw_material_entity.dart';

/// Raw materials data table that wraps the generic [AppDataTable].
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

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 56),
    AppTableColumn(label: 'Nomi', flex: 4, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Turi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Birlik', flex: 2),
    AppTableColumn(label: 'Qoldiq', flex: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<RawMaterialEntity>(
      items: materials,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, material, colIndex) =>
          _buildCell(context, material, colIndex),
    );
  }

  Widget _buildCell(
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

      case 3: // Birlik
        return Text(
          _unitLabel(material.unit),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        );

      case 4: // Qoldiq
        return _StockCell(value: material.stockQuantity);

      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------

class _StockCell extends StatelessWidget {
  const _StockCell({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final isPositive = value > 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final formatted = value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatted,
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
      'piece' => 'dona',
      _ => unit,
    };
