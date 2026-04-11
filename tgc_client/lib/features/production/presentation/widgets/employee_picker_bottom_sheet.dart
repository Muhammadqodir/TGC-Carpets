import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/search_picker_bottom_sheet.dart';
import '../../../employees/data/datasources/employee_remote_datasource.dart';
import '../../../employees/domain/entities/employee_entity.dart';

/// Searchable employee picker bottom sheet.
/// Returns the selected [EmployeeEntity] or null if dismissed.
class EmployeePickerBottomSheet {
  EmployeePickerBottomSheet._();

  static Future<EmployeeEntity?> show(BuildContext context) {
    return SearchPickerBottomSheet.show<EmployeeEntity>(
      context,
      title: 'Mas\'ul hodim',
      searchHint: 'Ism bo\'yicha qidirish...',
      onSearch: (query) async {
        final datasource = sl<EmployeeRemoteDataSource>();
        final result = await datasource.getEmployees(
          search: query.isEmpty ? null : query,
          perPage: 50,
        );
        return result.data;
      },
      itemBuilder: (context, employee) => _EmployeeTile(employee: employee),
      emptyText: 'Hodim topilmadi.',
      errorText: 'Hodimlar ro\'yxatini yuklashda xatolik.',
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final EmployeeEntity employee;

  const _EmployeeTile({required this.employee});

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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                employee.name.isNotEmpty
                    ? employee.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  employee.roleLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
