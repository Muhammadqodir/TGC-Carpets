import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A bottom sheet that lets users enter length and width as free-form integers.
/// Returns `({int length, int width})?` via [show], or null if dismissed.
class SizeInputSheet extends StatefulWidget {
  const SizeInputSheet({super.key, this.initialLength, this.initialWidth});

  final int? initialLength;
  final int? initialWidth;

  /// Convenience method to show the sheet and await the result.
  static Future<({int length, int width})?> show(
    BuildContext context, {
    int? initialLength,
    int? initialWidth,
  }) {
    return showModalBottomSheet<({int length, int width})?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizeInputSheet(
        initialLength: initialLength,
        initialWidth: initialWidth,
      ),
    );
  }

  @override
  State<SizeInputSheet> createState() => _SizeInputSheetState();
}

class _SizeInputSheetState extends State<SizeInputSheet> {
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _widthCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _lengthCtrl = TextEditingController(
      text: widget.initialLength != null ? '${widget.initialLength}' : '',
    );
    _widthCtrl = TextEditingController(
      text: widget.initialWidth != null ? '${widget.initialWidth}' : '',
    );
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final length = int.parse(_lengthCtrl.text.trim());
    final width = int.parse(_widthCtrl.text.trim());
    Navigator.of(context).pop((length: length, width: width));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'O\'lcham kiriting',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lengthCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Uzunlik (sm)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Majburiy';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Musbat son kiriting';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _widthCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Kenglik (sm)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Majburiy';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Musbat son kiriting';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Tasdiqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
