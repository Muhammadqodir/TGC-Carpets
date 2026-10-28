import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../widgets/shipment_form_controller.dart';
import '../widgets/shipment_item_row.dart';
import 'add_shipment_page.dart' show ShipmentRowNote;

/// The step between "Saqlash" and the shipment being written: the whole list
/// read once, the conflicts added up, and the optional note.
///
/// On the form the worker is scanning and only sees a screenful of rows at a
/// time, with the note box taking space at the bottom. Here nothing is
/// editable except the note, so this is a check, not more work. Pops `true`
/// to save; back keeps the form exactly as it was.
class ShipmentReviewPage extends StatelessWidget {
  const ShipmentReviewPage({
    super.key,
    required this.controller,
    required this.clientName,
    required this.date,
  });

  final ShipmentFormController controller;
  final String clientName;
  final String date;

  @override
  Widget build(BuildContext context) {
    final rows = controller.filledItems;
    final beyond = controller.totalBeyondClientOrders;
    final offOrder = rows
        .where((r) => r.isOffOrder)
        .fold<int>(0, (sum, r) => sum + r.parsedQuantity);
    final others = {for (final r in rows) ...r.producedForClients};
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Yuk xatini tasdiqlash')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            clientName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(date,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat(label: 'Mahsulot turi', value: '${rows.length}'),
              _Stat(label: 'Jami', value: '${controller.totalQuantity} dona'),
              _Stat(
                label: 'Maydon',
                value: '${controller.totalSqm.toStringAsFixed(2)} m²',
              ),
            ],
          ),
          if (beyond > 0 || offOrder > 0 || others.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Warning(lines: [
              if (beyond > 0)
                '$beyond dona mijoz buyurtmalaridan ortiqcha yuklanmoqda.',
              if (offOrder > 0) '$offOrder dona mijoz buyurtmasida yo\'q.',
              if (beyond > 0 || offOrder > 0)
                'Ular uchun "$clientName" mijoziga alohida buyurtma qatori '
                    'ochiladi.',
              if (others.isNotEmpty)
                '${others.join(', ')} uchun ishlab chiqarilgan gilamlar bor — '
                    'ularning tayyor soni kamayadi va buyurtmasi qayta ishlab '
                    'chiqarishga qaytadi.',
            ]),
          ],
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            color: AppColors.surface,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.divider),
                  _ReviewRow(row: rows[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Izoh (ixtiyoriy)',
              hintText: "Qo'shimcha ma'lumot...",
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.primary,
          ),
          icon: const Icon(Icons.check_rounded),
          label: Text('Tasdiqlash · ${controller.totalQuantity} dona'),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.row});

  final ShipmentItemRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (row.colorName != null) row.colorName!.toUpperCase(),
      if (row.sizeLabel != null) row.sizeLabel!,
      if (row.qualityName != null) row.qualityName!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppThumbnail(imageUrl: row.colorImageUrl, size: 36, borderRadius: 6),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.edgeCode != null
                      ? '${row.productName} [${row.edgeCode}]'
                      : row.productName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (details.isNotEmpty)
                  Text(details,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ShipmentRowNote(row: row),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${row.parsedQuantity}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          Text(value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              )),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lines.join('\n'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
