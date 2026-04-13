import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import '../../domain/entities/employee_entity.dart';

class EmployeeItem extends StatelessWidget {
  final EmployeeEntity employee;

  const EmployeeItem({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(employee.role);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          employee.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _RoleBadge(role: employee.role),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    employee.email,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (employee.phone != null && employee.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      employee.phone!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
        'admin' => AppColors.error,
        'warehouse' => AppColors.primary,
        'seller' => AppColors.accent,
        _ => Colors.grey,
      };
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'admin' => ('Admin', AppColors.error),
      'warehouse' => ('Ombor', AppColors.primary),
      'seller' => ('Sotuvchi', AppColors.accent),
      _ => (role, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
