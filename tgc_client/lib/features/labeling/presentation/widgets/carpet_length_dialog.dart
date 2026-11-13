import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/carpet_length.dart';
import '../../domain/entities/labeling_item_entity.dart';

/// Asks for the real length of the Kovrolin roll about to be labelled.
/// Returns it in cm, or null when the worker cancels: nothing prints then.
///
/// Starts from [lastCm], the length typed for this line last time, and never
/// from the nominal length, so a roll is never printed at 30 m because
/// someone pressed Enter without measuring.
Future<int?> showCarpetLengthDialog(
  BuildContext context, {
  required LabelingItemEntity item,
  int? lastCm,
}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _CarpetLengthDialog(item: item, lastCm: lastCm),
    );

class _CarpetLengthDialog extends StatefulWidget {
  const _CarpetLengthDialog({required this.item, this.lastCm});

  final LabelingItemEntity item;
  final int? lastCm;

  @override
  State<_CarpetLengthDialog> createState() => _CarpetLengthDialogState();
}

class _CarpetLengthDialogState extends State<_CarpetLengthDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.lastCm == null ? '' : formatCarpetLengthMetres(widget.lastCm!),
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final cm = parseCarpetLengthMetres(_controller.text);
    final error = carpetLengthError(cm, widget.item.sizeLength);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(cm);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final nominal = item.sizeLength;

    return AlertDialog(
      title: const Text('Haqiqiy uzunlik'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.productName} · ${item.nominalSizeLabel}'
              '${item.colorName == null ? '' : ' · ${item.colorName}'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Uzunlik',
                suffixText: 'm',
                helperText: nominal == null
                    ? null
                    : 'Reja bo\'yicha: ${formatCarpetLengthMetres(nominal)} m',
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Chop etish'),
        ),
      ],
    );
  }
}
