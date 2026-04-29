import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';
import '../../../../core/constants/app_constants.dart';
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
    AppTableColumn(label: 'ID', fixedWidth: 40, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Partiya nomi', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Tur', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Stanok', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holat', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Reja sanasi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Jami dona', fixedWidth: 90, alignment: Alignment.center),
    AppTableColumn(
        label: 'Jami m²', fixedWidth: 100, alignment: Alignment.center),
    AppTableColumn(
        label: 'Amallar', fixedWidth: 100, alignment: Alignment.center),
  ];

  static const _columnsMobile = <AppTableColumn>[
    AppTableColumn(label: 'Partiya', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Holat', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: '', fixedWidth: 40, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      final columns = isDesktop ? _columns : _columnsMobile;

      return AppDataTable<ProductionBatchEntity>(
        items: batches,
        columns: columns,
        scrollController: scrollController,
        isLoadingMore: isLoadingMore,
        cellBuilder: (context, batch, colIndex) =>
            _buildCell(context, batch, colIndex, isDesktop),
      );
    });
  }

  Widget _buildCell(BuildContext context, ProductionBatchEntity batch,
      int colIndex, bool isDesktop) {
    if (!isDesktop) {
      return _buildMobileCell(context, batch, colIndex);
    }
    return _buildDesktopCell(context, batch, colIndex);
  }

  Widget _buildDesktopCell(
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
            '${batch.totalPlannedQuantity}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        );

      case 7:
        return Center(
          child: Text(
            batch.totalSqm > 0
                ? '${batch.totalSqm.toStringAsFixed(2)} m²'
                : '—',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: batch.totalSqm > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
          ),
        );

      case 8:
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

  Widget _buildMobileCell(
    BuildContext context,
    ProductionBatchEntity batch,
    int colIndex,
  ) {
    switch (colIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BodyText(
              text: '#${batch.id} · ${batch.batchTitle}',
              fontWeight: FontWeight.bold,
            ),
            BodyText(
              text: [
                if (batch.plannedDatetime != null)
                  _formatDate(batch.plannedDatetime!),
                if (batch.machine != null) batch.machine!.name,
                batch.typeLabel,
              ].join(' · '),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatusChip(status: batch.status),
            SubBodyText(
              text: '${batch.totalPlannedQuantity} dona'
                  '${batch.totalSqm > 0 ? ' · ${batch.totalSqm.toStringAsFixed(1)} m²' : ''}',
            ),
          ],
        );

      case 2:
        return PopupMenuButton<String>(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedMoreVertical,
            size: 20,
          ),
          surfaceTintColor: AppColors.surface,
          color: AppColors.surface,
          onSelected: (value) {
            switch (value) {
              case 'view':
                onView?.call(batch);
                break;
              case 'edit':
                onEdit?.call(batch);
                break;
            }
          },
          itemBuilder: (context) => [
            if (onView != null)
              const PopupMenuItem(
                value: 'view',
                child: Text('Tafsilotlar'),
              ),
            if (batch.status == 'planned' && onEdit != null)
              const PopupMenuItem(
                value: 'edit',
                child: Text('Tahrirlash'),
              ),
          ],
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
      'planned' => ('Rejalashtirilgan', AppColors.textSecondary),
      'in_progress' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'completed' => ('Bajarildi', AppColors.success),
      'cancelled' => ('Bekor qilindi', AppColors.error),
      _ => (status, AppColors.textSecondary),
    };

    return AppBadge(
      label: label,
      color: color,
    );
  }
}
