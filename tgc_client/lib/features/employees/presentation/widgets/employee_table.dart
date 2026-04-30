import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/features/employees/domain/entities/employee_entity.dart';

/// Employee-specific data table that wraps the generic [AppDataTable].
/// Adapts between desktop (6 columns) and mobile (3 columns) layouts.
class EmployeeDataTable extends StatelessWidget {
  const EmployeeDataTable({
    super.key,
    required this.employees,
    required this.isLoadingMore,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
    this.pendingEmployeeId,
  });

  final List<EmployeeEntity> employees;
  final bool isLoadingMore;
  final ScrollController scrollController;
  final void Function(EmployeeEntity) onEdit;
  final void Function(EmployeeEntity) onDelete;
  final int? pendingEmployeeId;

  static const _desktopColumns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 52),
    AppTableColumn(label: 'Ism', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Email', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Telefon', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Rol', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Amallar', fixedWidth: 88),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(label: 'Ism / Rol', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Email / Telefon', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Amallar', fixedWidth: 88),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;
        return AppDataTable<EmployeeEntity>(
          items: employees,
          columns: isMobile ? _mobileColumns : _desktopColumns,
          scrollController: scrollController,
          isLoadingMore: isLoadingMore,
          cellBuilder: (context, employee, colIndex) => isMobile
              ? _buildMobileCell(context, employee, colIndex)
              : _buildDesktopCell(context, employee, colIndex),
        );
      },
    );
  }

  Widget _buildDesktopCell(BuildContext context, EmployeeEntity employee, int colIndex) {
    final isPending = pendingEmployeeId == employee.id;
    switch (colIndex) {
      case 0: // id
        return Text(
          employee.id.toString(),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        );
      case 1: // name
        return Text(
          employee.name,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        );
      case 2: // email
        return Text(
          employee.email,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
          overflow: TextOverflow.ellipsis,
        );
      case 3: // phone
        return Text(
          employee.phone ?? '—',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(fontFamily: 'monospace'),
          overflow: TextOverflow.ellipsis,
        );
      case 4: // role
        return AppBadge(
          label: employee.roleLabel,
          color: _getRoleColor(employee.role),
        );
      case 5: // actions
        if (isPending) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: AppColors.primary,
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'Tahrirlash',
              onTap: () => onEdit(employee),
            ),
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'O\'chirish',
              onTap: () => onDelete(employee),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMobileCell(BuildContext context, EmployeeEntity employee, int colIndex) {
    final isPending = pendingEmployeeId == employee.id;
    switch (colIndex) {
      case 0: // name / role
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              employee.name,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            AppBadge(
              label: employee.roleLabel,
              color: _getRoleColor(employee.role),
            ),
          ],
        );
      case 1: // email / phone
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              employee.email,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              employee.phone ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontFamily: 'monospace', color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        );
      case 2: // actions
        if (isPending) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: AppColors.primary,
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'Tahrirlash',
              onTap: () => onEdit(employee),
            ),
            _ActionButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
                strokeWidth: 1.5,
                size: 20,
              ),
              tooltip: 'O\'chirish',
              onTap: () => onDelete(employee),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color _getRoleColor(String role) {
    return switch (role) {
      'admin' => AppColors.error,
      'warehouse' => AppColors.accent,
      'seller' => AppColors.success,
      _ => AppColors.textSecondary,
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: icon,
        ),
      ),
    );
  }
}
