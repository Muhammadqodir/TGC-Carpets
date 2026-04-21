import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A dialog that checks attribute usage and, when products are found,
/// requires the user to pick a replacement before deletion.
///
/// Returns `(confirmed: bool, replaceWithId: int?)`:
/// - `confirmed == false` → user cancelled
/// - `confirmed == true, replaceWithId == null` → no dependents; plain delete
/// - `confirmed == true, replaceWithId != null` → replace before delete
class DeleteWithReplaceDialog<T> extends StatefulWidget {
  const DeleteWithReplaceDialog({
    super.key,
    required this.itemName,
    required this.attributeTypeName,
    required this.usageFuture,
    required this.replacements,
    required this.replacementLabel,
    required this.replacementId,
  });

  /// Label of the item being deleted (e.g. "Qizil").
  final String itemName;

  /// Localized attribute type name shown in messages (e.g. "rang", "tur").
  final String attributeTypeName;

  /// Future that resolves to the number of products currently using this item.
  final Future<int> usageFuture;

  /// List of available replacement items (excludes the item being deleted).
  final List<T> replacements;

  /// Returns the display label for a replacement item.
  final String Function(T item) replacementLabel;

  /// Returns the ID for a replacement item.
  final int Function(T item) replacementId;

  /// Shows the dialog and returns `(confirmed, replaceWithId)`.
  static Future<({bool confirmed, int? replaceWithId})> show<T>({
    required BuildContext context,
    required String itemName,
    required String attributeTypeName,
    required Future<int> usageFuture,
    required List<T> replacements,
    required String Function(T item) replacementLabel,
    required int Function(T item) replacementId,
  }) async {
    final result = await showDialog<({bool confirmed, int? replaceWithId})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteWithReplaceDialog<T>(
        itemName: itemName,
        attributeTypeName: attributeTypeName,
        usageFuture: usageFuture,
        replacements: replacements,
        replacementLabel: replacementLabel,
        replacementId: replacementId,
      ),
    );
    return result ?? (confirmed: false, replaceWithId: null);
  }

  @override
  State<DeleteWithReplaceDialog<T>> createState() =>
      _DeleteWithReplaceDialogState<T>();
}

class _DeleteWithReplaceDialogState<T>
    extends State<DeleteWithReplaceDialog<T>> {
  T? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '"${widget.itemName}" ni o\'chirish',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      content: FutureBuilder<int>(
        future: widget.usageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final count = snapshot.data ?? 0;
          final hasError = snapshot.hasError;

          if (hasError) {
            return const Text(
              'Foydalanish sonini tekshirib bo\'lmadi. Davom ettirishni xohlaysizmi?',
            );
          }

          if (count == 0) {
            return Text(
              '"${widget.itemName}" ${widget.attributeTypeName}i hech qanday mahsulotda ishlatilmayapti. '
              'O\'chirishni tasdiqlaysizmi?',
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: '"${widget.itemName}" ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: '${widget.attributeTypeName}i ',
                    ),
                    TextSpan(
                      text: '$count ta ',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text: 'mahsulotda ishlatilmoqda. '
                          'O\'chirishdan oldin boshqa variantni tanlang:',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<T>(
                value: _selected,
                decoration: InputDecoration(
                  labelText: 'Almashtirish uchun ${widget.attributeTypeName}',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: widget.replacements
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(widget.replacementLabel(item)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selected = value),
                validator: (v) =>
                    v == null ? 'Iltimos, almashtirish variantini tanlang' : null,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop((confirmed: false, replaceWithId: null)),
          child: const Text('Bekor qilish'),
        ),
        FutureBuilder<int>(
          future: widget.usageFuture,
          builder: (context, snapshot) {
            final count = snapshot.data ?? -1;
            final isLoading = snapshot.connectionState != ConnectionState.done;
            final needsReplacement = count > 0;
            final canConfirm =
                !isLoading && (!needsReplacement || _selected != null);

            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: canConfirm
                  ? () {
                      final replaceWithId = _selected != null
                          ? widget.replacementId(_selected as T)
                          : null;
                      Navigator.of(context).pop(
                        (confirmed: true, replaceWithId: replaceWithId),
                      );
                    }
                  : null,
              child: Text(
                needsReplacement && _selected != null
                    ? 'Almashtir va o\'chir'
                    : 'O\'chirish',
              ),
            );
          },
        ),
      ],
    );
  }
}
