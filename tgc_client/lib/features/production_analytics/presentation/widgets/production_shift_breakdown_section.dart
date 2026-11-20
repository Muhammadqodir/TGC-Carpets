import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/production_shift_breakdown.dart';

/// A shift-by-shift table: each shift's lines (qualities, or Kovrolin roll
/// widths) with count and m², then the shift's subtotal.
class ProductionShiftBreakdownSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;

  /// Header of the line column, e.g. "Sifat" or "Eni".
  final String lineHeader;

  /// Header of the count column, e.g. "Dona" or "Rulon".
  final String countHeader;
  final List<ShiftBreakdownGroup> groups;
  final String emptyText;

  const ProductionShiftBreakdownSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.lineHeader,
    this.countHeader = 'Dona',
    required this.groups,
    required this.emptyText,
  });

  /// Below this width the shift heads its own lines instead of taking a
  /// column, so the numbers keep the room they need on a phone.
  static const narrowWidth = 520.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final header = small?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary);
    final body = theme.textTheme.bodyMedium;
    final bold = body?.copyWith(fontWeight: FontWeight.w600);

    final totalQty = groups.fold<int>(0, (s, g) => s + g.totalQuantity);
    final totalSqm = groups.fold<double>(0, (s, g) => s + g.totalSqm);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(42, 2, 16, 0),
              child: Text(subtitle!, style: small?.copyWith(color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(emptyText, style: small?.copyWith(color: AppColors.textSecondary)),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < narrowWidth;

                // Shift column only on a wide screen; numbers never wrap.
                Widget row(String shift, String line, String count, String sqm,
                        {TextStyle? style, Color? color}) =>
                    Container(
                      color: color,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      child: Row(
                        children: [
                          if (!narrow)
                            Expanded(flex: 4, child: Text(shift, style: style, overflow: TextOverflow.ellipsis)),
                          Expanded(
                            flex: narrow ? 5 : 3,
                            child: Text(line, style: style, maxLines: narrow ? 2 : 1, overflow: TextOverflow.ellipsis),
                          ),
                          Expanded(flex: 2, child: _number(count, style)),
                          Expanded(flex: narrow ? 3 : 2, child: _number(sqm, style)),
                        ],
                      ),
                    );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    row('Smena', lineHeader, countHeader, 'm²', style: header),
                    const Divider(height: 1, color: AppColors.divider),
                    for (final g in groups) ...[
                      if (narrow)
                        Container(
                          color: AppColors.primary.withAlpha(8),
                          padding: const EdgeInsets.fromLTRB(16, 9, 16, 5),
                          child: Text(
                            g.shiftName,
                            style: bold?.copyWith(color: AppColors.primary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      for (final (i, l) in g.lines.indexed)
                        row(i == 0 ? g.shiftName : '', l.label, formatQty(l.quantity), formatSqm(l.sqm),
                            style: body),
                      if (g.lines.length > 1)
                        row('', 'Jami', formatQty(g.totalQuantity), formatSqm(g.totalSqm),
                            style: bold, color: AppColors.background),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                    // Without the shift column the label moves to the line column.
                    row(narrow ? '' : 'Hammasi', narrow ? 'Hammasi' : '', formatQty(totalQty),
                        formatSqm(totalSqm), style: bold, color: AppColors.primary.withAlpha(18)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// A right-aligned figure on one line: scaled down rather than wrapped
  /// or cut if a column is ever too narrow for it.
  static Widget _number(String text, TextStyle? style) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(text, style: style, maxLines: 1, softWrap: false),
        ),
      );
}
