import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/label_print_queue.dart';

/// "01.11 14:05" — how a print time reads on the labeling screens.
String labelPrintTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

/// Asks before taking a label back. True when the operator confirmed.
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

/// The carpet labels this shift printed lately, newest first, each one a
/// tap away from being taken back. Pops with the label picked, or null.
class LabelUndoSheet extends StatelessWidget {
  const LabelUndoSheet({super.key, required this.queue, required this.userId});

  final LabelPrintQueue queue;
  final int userId;

  static Future<RecentLabelPrint?> show(
    BuildContext context, {
    required LabelPrintQueue queue,
    required int userId,
  }) {
    return showModalBottomSheet<RecentLabelPrint>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LabelUndoSheet(queue: queue, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prints = queue.recentFor(userId);
    final hours = LabelPrintQueue.undoWindow.inHours;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chop etishni bekor qilish',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Oxirgi $hours soatda chop etilgan yorliqlar',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: prints.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Bekor qilinadigan yorliq yo\'q.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: prints.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = prints[i];
                      return ListTile(
                        title: Text('${p.productName} ${p.sizeLabel ?? ''}'),
                        subtitle: Text(labelPrintTime(p.printedAt)),
                        trailing: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(p),
                          icon: const Icon(Icons.undo_rounded, size: 18),
                          label: const Text('Bekor qilish'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
