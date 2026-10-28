import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A dialog that checks attribute usage and, when products are found, lets
/// the user either pick a replacement or hide the attribute as it is.
///
/// Returns `(confirmed: bool, replaceWithId: int?, hide: bool)`:
/// - `confirmed == false` → user cancelled
/// - `confirmed == true, replaceWithId == null, hide == false` → no dependents; plain delete
/// - `confirmed == true, replaceWithId != null` → replace before delete
/// - `confirmed == true, hide == true` → hide (soft-delete) without touching
///   the products that use it
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

  /// Shows the dialog and returns `(confirmed, replaceWithId, hide)`.
  static Future<({bool confirmed, int? replaceWithId, bool hide})> show<T>({
    required BuildContext context,
    required String itemName,
    required String attributeTypeName,
    required Future<int> usageFuture,
    required List<T> replacements,
    required String Function(T item) replacementLabel,
    required int Function(T item) replacementId,
  }) async {
    final result =
        await showDialog<({bool confirmed, int? replaceWithId, bool hide})>(
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
    return result ?? (confirmed: false, replaceWithId: null, hide: false);
  }

  @override
  State<DeleteWithReplaceDialog<T>> createState() =>
      _DeleteWithReplaceDialogState<T>();
}

enum _Mode { replace, hide }

class _DeleteWithReplaceDialogState<T>
    extends State<DeleteWithReplaceDialog<T>> {
  T? _selected;
  _Mode _mode = _Mode.replace;

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
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: FutureBuilder<int>(
          future: widget.usageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final count = snapshot.data ?? 0;

            if (snapshot.hasError) {
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

            return SingleChildScrollView(
              child: RadioGroup<_Mode>(
                groupValue: _mode,
                onChanged: (m) => setState(() => _mode = m ?? _mode),
                child: Column(
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
                          TextSpan(text: '${widget.attributeTypeName}i '),
                          TextSpan(
                            text: '$count ta ',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                            text:
                                'mahsulotda ishlatilmoqda. Qanday davom etamiz?',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Option 1: replace, then delete ───────────────────────
                    const RadioListTile<_Mode>(
                      value: _Mode.replace,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Boshqasiga almashtirib o\'chirish'),
                    ),
                    if (_mode == _Mode.replace)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: DropdownButtonFormField<T>(
                          value: _selected,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText:
                                'Almashtirish uchun ${widget.attributeTypeName}',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                          items: widget.replacements
                              .map(
                                (item) => DropdownMenuItem<T>(
                                  value: item,
                                  child: Text(widget.replacementLabel(item)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selected = value),
                        ),
                      ),

                    // ── Option 2: hide, change nothing ───────────────────────
                    const RadioListTile<_Mode>(
                      value: _Mode.hide,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Almashtirmasdan o\'chirish (yashirish)'),
                    ),
                    if (_mode == _Mode.hide)
                      _HideWarning(
                          count: count, typeName: widget.attributeTypeName),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context)
              .pop((confirmed: false, replaceWithId: null, hide: false)),
          child: const Text('Bekor qilish'),
        ),
        FutureBuilder<int>(
          future: widget.usageFuture,
          builder: (context, snapshot) {
            final count = snapshot.data ?? -1;
            final isLoading = snapshot.connectionState != ConnectionState.done;
            final inUse = count > 0;
            final hide = inUse && _mode == _Mode.hide;
            final canConfirm =
                !isLoading && (!inUse || hide || _selected != null);

            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: hide ? AppColors.warning : AppColors.error,
              ),
              onPressed: canConfirm
                  ? () {
                      final replaceWithId = !hide && _selected != null
                          ? widget.replacementId(_selected as T)
                          : null;
                      Navigator.of(context).pop(
                        (
                          confirmed: true,
                          replaceWithId: replaceWithId,
                          hide: hide
                        ),
                      );
                    }
                  : null,
              child: Text(
                hide
                    ? 'Yashirish'
                    : inUse && _selected != null
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

class _HideWarning extends StatelessWidget {
  const _HideWarning({required this.count, required this.typeName});

  final int count;
  final String typeName;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: style),
              Expanded(child: Text(text, style: style)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(left: 8, top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'Diqqat',
                style: style?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          line('Bu $typeName ro\'yxatlardan va tanlash oynalaridan yo\'qoladi: '
              'yangi mahsulot, buyurtma yoki partiyada uni tanlab bo\'lmaydi.'),
          line('Uni ishlatayotgan $count ta mahsulot, ularning buyurtmalari, '
              'qoldiqlari va yorliqlari o\'zgarmaydi — eski nomi bilan ko\'rinishda qoladi.'),
          line('Hisobotlar va statistikada ham avvalgidek ko\'rinadi.'),
          line(
              'Xato bo\'lsa: shu nomni qayta qo\'shing — u barcha bog\'lanishlari bilan qaytadi.'),
        ],
      ),
    );
  }
}
