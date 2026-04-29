import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Adaptive table header for warehouse document form.
/// Shows full column set on desktop, minimal on mobile.
class WarehouseDocumentFormTableHeader extends StatelessWidget {
  const WarehouseDocumentFormTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppConstants.desktopBreakpoint;
        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (isDesktop) ...[
                const _HeaderCell(label: '#', fixedWidth: 40),
                const _HeaderCell(label: 'Mahsulot', flex: 1),
                const _HeaderCell(label: 'Sifat / Tur', flex: 1),
                const _HeaderCell(label: 'O\'lcham', flex: 1),
                const _HeaderCell(label: 'Mijoz / Partiya', flex: 1),
                const _HeaderCell(label: 'Miqdor', fixedWidth: 130),
              ] else ...[
                const _HeaderCell(label: 'Mahsulot', flex: 2),
                const _HeaderCell(label: 'Miqdor', fixedWidth: 130),
              ],
              const SizedBox(width: 40),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int? flex;
  final double? fixedWidth;

  const _HeaderCell({required this.label, this.flex, this.fixedWidth});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
    );
    if (fixedWidth != null) {
      return SizedBox(width: fixedWidth, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}
