import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/label_print_queue.dart';

/// "01.11 14:05" — how a print time reads on the labeling screens.
String labelPrintTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

/// Asks before taking a label back with Ctrl/⌘+Z, where no card shows
/// which one. True when the operator confirmed.
Future<bool> confirmLabelUndo(BuildContext context, RecentLabelPrint print) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chop etishni bekor qilish'),
      content: Text(
        '${print.productName} ${print.sizeLabel ?? ''} · ${labelPrintTime(print.printedAt)}\n\n'
        'Gilam soni bittaga kamayadi. Chop etilgan yorliqni yo\'q qiling.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Yo\'q'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Bekor qilish'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Where one corner card is: offering the undo, or saying how it went.
enum LabelUndoToastStatus { offered, undone, unavailable }

/// The card in the corner after a carpet label is printed: what was
/// printed, a bar running down for [duration], and the undo button. After
/// the undo it says so, and tells the worker to throw the label away.
class LabelUndoToast extends StatelessWidget {
  const LabelUndoToast({
    super.key,
    required this.label,
    required this.status,
    required this.duration,
    required this.onUndo,
    required this.onClose,
  });

  /// "1568 200×300".
  final String label;
  final LabelUndoToastStatus status;

  /// How long the card stays; the bar runs down over it.
  final Duration duration;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title, subtitle) = switch (status) {
      LabelUndoToastStatus.offered => (
          Icons.check_circle_rounded,
          AppColors.success,
          'Chop etildi',
          label,
        ),
      LabelUndoToastStatus.undone => (
          Icons.undo_rounded,
          AppColors.primary,
          'Bekor qilindi: $label',
          'Chop etilgan yorliqni yo\'q qiling.',
        ),
      LabelUndoToastStatus.unavailable => (
          Icons.info_outline_rounded,
          AppColors.warning,
          'Bekor qilib bo\'lmadi',
          'Bu yorliq allaqachon bekor qilingan.',
        ),
    };

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (status == LabelUndoToastStatus.offered) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onUndo,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: const Text('Bekor qilish'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Yopish',
                    visualDensity: VisualDensity.compact,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            // Restarts whenever the status (and so the duration) changes.
            TweenAnimationBuilder<double>(
              key: ValueKey(status),
              tween: Tween(begin: 1, end: 0),
              duration: duration,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
