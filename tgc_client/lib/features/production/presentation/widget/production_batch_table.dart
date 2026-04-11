import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_data_table.dart';
import '../../domain/entities/production_batch_entity.dart';

class ProductionBatchTable extends StatelessWidget {
  final List<ProductionBatchEntity> batches;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(ProductionBatchEntity) onViewDetail;
  final void Function(ProductionBatchEntity)? onEdit;

  const ProductionBatchTable({
    super.key,
    required this.batches,
    this.isLoadingMore = false,
    required this.scrollController,
    required this.onViewDetail,
    this.onEdit,
  });

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: '#', fixedWidth: 50),
    AppTableColumn(label: 'Nomi', flex: 3),
    AppTableColumn(label: 'Mashina', flex: 2),
    AppTableColumn(label: 'Tur', flex: 2),
    AppTableColumn(label: 'Holat', flex: 2),
    AppTableColumn(label: 'Reja', flex: 2),
    AppTableColumn(label: 'Mahsulotlar', fixedWidth: 90, alignment: Alignment.center),
    AppTableColumn(label: '', fixedWidth: 100),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<ProductionBatchEntity>(
      items: batches,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, batch, colIndex) {
        return switch (colIndex) {
          0 => Text(
              '${batch.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          1 => GestureDetector(
              onTap: () => onViewDetail(batch),
              child: Text(
                batch.batchTitle,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          2 => Text(
              batch.machineName ?? '—',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          3 => _TypeBadge(type: batch.type),
          4 => _StatusBadge(status: batch.status),
          5 => Text(
              batch.plannedDatetime != null
                  ? _formatDateTime(batch.plannedDatetime!)
                  : '—',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          6 => Text(
              '${batch.effectiveItemsCount}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          7 => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  onPressed: () => onViewDetail(batch),
                  tooltip: 'Ko\'rish',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                if (onEdit != null && batch.status == 'planned')
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => onEdit!(batch),
                    tooltip: 'Tahrirlash',
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'planned' => ('Rejalashtirilgan', AppColors.warning),
      'in_progress' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'completed' => ('Yakunlangan', AppColors.success),
      'cancelled' => ('Bekor qilingan', AppColors.error),
      _ => (status, AppColors.textSecondary),
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

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      'by_order' => 'Buyurtma',
      'for_stock' => 'Zaxira',
      'mixed' => 'Aralash',
      _ => type,
    };

    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
    );
  }
}
