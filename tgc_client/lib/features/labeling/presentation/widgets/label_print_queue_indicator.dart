import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/label_print_queue.dart';

/// App-bar badge for [LabelPrintQueue]: green when every printed label is on
/// the server, orange with a count while some are on their way, red when
/// the server refused one. Tapping it lists what is still waiting.
class LabelPrintQueueIndicator extends StatelessWidget {
  const LabelPrintQueueIndicator({super.key, required this.queue});

  final LabelPrintQueue queue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LabelPrintQueueUpdate>(
      stream: queue.updates,
      builder: (context, _) {
        final unsent = queue.unsentCount;
        final failed = queue.failedCount;
        final color = failed > 0
            ? AppColors.error
            : unsent > 0
                ? AppColors.warning
                : AppColors.success;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextButton.icon(
            onPressed: () => _showQueue(context),
            style: TextButton.styleFrom(foregroundColor: color),
            icon: HugeIcon(
              icon: unsent > 0
                  ? HugeIcons.strokeRoundedCloudUpload
                  : HugeIcons.strokeRoundedCloudSavingDone01,
              color: color,
              strokeWidth: 2,
              size: 20,
            ),
            label: Text(unsent > 0 ? '$unsent' : 'Yozildi'),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context) {
    queue.wake();
    showDialog<void>(
      context: context,
      builder: (ctx) => StreamBuilder<LabelPrintQueueUpdate>(
        stream: queue.updates,
        builder: (ctx, _) {
          final waiting =
              queue.entries.where((e) => e.status != QueuedPrintStatus.sent).toList().reversed.toList();

          return AlertDialog(
            title: const Text('Serverga yuborish navbati'),
            content: SizedBox(
              width: 440,
              child: waiting.isEmpty
                  ? const Text('Barcha chop etilgan yorliqlar serverga yozildi.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: waiting.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _QueueRow(entry: waiting[i], queue: queue),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: queue.wake,
                child: const Text('Hozir yuborish'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Yopish'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.entry, required this.queue});

  final QueuedLabelPrint entry;
  final LabelPrintQueue queue;

  @override
  Widget build(BuildContext context) {
    final t = entry.printedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
    final failed = entry.status == QueuedPrintStatus.failed;
    final status = switch (entry.status) {
      QueuedPrintStatus.printing => 'chop etilmoqda',
      QueuedPrintStatus.pending => entry.lastError == null ? 'navbatda' : 'qayta urinish: ${entry.lastError}',
      QueuedPrintStatus.sent => 'yozildi',
      QueuedPrintStatus.failed => 'server rad etdi: ${entry.lastError ?? ''}',
    };

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${entry.productName} ${entry.sizeLabel ?? ''}${entry.reprint ? ' · qayta' : ''}',
      ),
      subtitle: Text(
        '$time · $status',
        style: TextStyle(color: failed ? AppColors.error : AppColors.textSecondary),
      ),
      trailing: failed
          ? IconButton(
              tooltip: 'Navbatdan olib tashlash',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Navbatdan olib tashlansinmi?'),
                    content: const Text(
                      'Bu yorliq serverga yozilmaydi. Faqat partiya qatori o\'chirilgan bo\'lsa olib tashlang.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Bekor qilish')),
                      FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Olib tashlash')),
                    ],
                  ),
                );
                if (ok == true) await queue.remove(entry.key);
              },
            )
          : null,
    );
  }
}
