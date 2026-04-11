import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_data_table.dart';
import '../../domain/entities/production_batch_entity.dart';

class ProductionBatchTable extends StatelessWidget {
  const ProductionBatchTable({
    super.key,
    required this.batches,
    required this.isLoadingMore,
    required this.scrollController,
    this.onView,
    this.onEdit,
  });

  final List<ProductionBatchEntity> batches;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ProductionBatchEntity)? onView;
  final void Function(ProductionBatchEntity)? onEdit;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID',          fixedWidth: 68,  alignment: Alignment.center),
    AppTableColumn(label: 'Batch nomi',  flex: 3,         alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Tur',         flex: 2,         alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Stanok',      flex: 2,         alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holat',       flex: 2,         alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Reja sanasi', flex: 2,         alignment: Alignment.centerLeft),
    AppTableColumn(label: "Mahsulotlar", flex: 1,         alignment: Alignment.center),
    AppTableColumn(label: 'Amallar',     fixedWidth: 100, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<ProductionBatchEntity>(
      items:            batches,
      columns:          _columns,
      scrollController: scrollController,
      isLoadingMore:    isLoadingMore,
      cellBuilder: (context, batch, colIndex) =>
          _buildCell(context, batch, colIndex),
    );
  }

  Widget _buildCell(
      BuildContext context, ProductionBatchEntity batch, int colIndex) {
    switch (colIndex) {
      case 0:
        return Text(
          '${batch.id}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        );

      case 1:
        return Text(
          batch.batchTitle,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );

      case 2:
        return Text(
          batch.typeLabel,
          style: Theme.of(context).textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

      case 3:
        return batch.machine != null
            ? Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      batch.machine!.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(
                '—',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              );

      case 4:
        return _StatusChip(status: batch.status);

      case 5:
        return batch.plannedDatetime != null
            ? Text(
                _formatDate(batch.plannedDatetime!),
                style: Theme.of(context).textTheme.bodyMedium,
              )
            : Text(
                '—',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              );

      case 6:
        return Center(
          child: Text(
            '${batch.itemsCount}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

      case 7:
        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onView != null)
                IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    color: AppColors.primaryLight,
                  ),
                  onPressed: () => onView!(batch),
                  tooltip: 'Tafsilotlar',
                ),
              if (batch.status == 'planned' && onEdit != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedEdit02,
                    color: AppColors.warning,
                  ),
                  onPressed: () => onEdit!(batch),
                  tooltip: 'Tahrirlash',
                ),
              ],
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Status chip ───────────────────────────────────────────────────────────────

class ProductionBatchStatusChip extends StatelessWidget {
  const ProductionBatchStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => _StatusChip(status: status);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'planned'     => ('Rejalashtirilgan',     AppColors.textSecondary),
      'in_progress' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'completed'   => ('Bajarildi',            AppColors.success),
      'cancelled'   => ('Bekor qilindi',        AppColors.error),
      _             => (status,                 AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
