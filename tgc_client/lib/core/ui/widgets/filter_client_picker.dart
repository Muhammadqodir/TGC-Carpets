import 'package:flutter/material.dart';

import '../../../../features/clients/domain/entities/client_entity.dart';
import '../../../../features/clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../theme/app_colors.dart';

/// Reusable client-picker button for desktop filter bars.
///
/// Opens [ClientPickerBottomSheet] on tap and surfaces the selected
/// [ClientEntity].  When selected, shows the client name with an inline ×
/// button to clear, identical to the order filter bar pattern.
class FilterClientPicker extends StatelessWidget {
  const FilterClientPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Mijoz',
  });

  final ClientEntity? value;
  final ValueChanged<ClientEntity?> onChanged;

  /// Placeholder text shown when no client is selected.
  final String hint;

  @override
  Widget build(BuildContext context) {
    final isSelected = value != null;
    return InkWell(
      onTap: () async {
        final picked = await ClientPickerBottomSheet.show(context);
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_outlined,
              size: 14,
              color:
                  isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              isSelected ? value!.shopName : hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
