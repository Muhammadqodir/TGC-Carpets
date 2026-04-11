import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/search_picker_bottom_sheet.dart';
import '../../data/datasources/production_batch_remote_datasource.dart';
import '../../domain/entities/production_batch_entity.dart';

/// Searchable machine (Stanok) picker bottom sheet.
/// Returns the selected [ProductionBatchMachine] or null if dismissed.
class MachinePickerBottomSheet {
  MachinePickerBottomSheet._();

  static Future<ProductionBatchMachine?> show(BuildContext context) {
    return SearchPickerBottomSheet.show<ProductionBatchMachine>(
      context,
      title: 'Stanok tanlash',
      searchHint: 'Stanok nomi...',
      onSearch: (query) async {
        final datasource = sl<ProductionBatchRemoteDataSource>();
        return datasource.getMachines(
          search: query.isEmpty ? null : query,
        );
      },
      itemBuilder: (context, machine) => _MachineTile(machine: machine),
      emptyText: 'Stanok topilmadi.',
      errorText: 'Stanoklar ro\'yxatini yuklashda xatolik.',
    );
  }
}

class _MachineTile extends StatelessWidget {
  final ProductionBatchMachine machine;

  const _MachineTile({required this.machine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.precision_manufacturing_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (machine.modelName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    machine.modelName!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
