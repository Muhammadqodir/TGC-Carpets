import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/production_batch_entity.dart';
import 'production_batch_table.dart';

class ProductionBatchCard extends StatelessWidget {
  const ProductionBatchCard({
    super.key,
    required this.batch,
    this.onTap,
    this.onEdit,
  });

  final ProductionBatchEntity batch;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: ID + status + edit action
              Row(
                children: [
                  Text(
                    '#${batch.id}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(width: 10),
                  ProductionBatchStatusChip(status: batch.status),
                  const Spacer(),
                  if (batch.status == 'planned' && onEdit != null)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.primaryLight),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Tahrirlash',
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Batch title
              Text(
                batch.batchTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Type
              Row(
                children: [
                  const Icon(Icons.category_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    batch.typeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Machine
              Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      batch.machine?.name ?? '—',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Planned date
              if (batch.plannedDatetime != null) ...[
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(batch.plannedDatetime!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],

              // Items count + view hint
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${batch.itemsCount} ta mahsulot',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    "Ko'proq",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryLight,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 14, color: AppColors.primaryLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
