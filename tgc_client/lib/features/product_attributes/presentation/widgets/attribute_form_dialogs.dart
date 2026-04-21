import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/domain/entities/product_type_entity.dart';
import '../bloc/product_attributes_state.dart';

/// Generic single-field attribute form dialog (Color, ProductType).
class SimpleAttributeFormDialog extends StatefulWidget {
  const SimpleAttributeFormDialog({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.fieldHint,
    this.initialValue,
    required this.onSubmit,
  });

  final String title;
  final String fieldLabel;
  final String fieldHint;
  final String? initialValue;
  final void Function(BuildContext context, String value) onSubmit;

  static void show(
    BuildContext context, {
    required String title,
    required String fieldLabel,
    required String fieldHint,
    String? initialValue,
    required void Function(BuildContext context, String value) onSubmit,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SimpleAttributeFormDialog(
        title: title,
        fieldLabel: fieldLabel,
        fieldHint: fieldHint,
        initialValue: initialValue,
        onSubmit: (ctx, value) => onSubmit(ctx, value),
      ),
    );
  }

  @override
  State<SimpleAttributeFormDialog> createState() => _SimpleAttributeFormDialogState();
}

class _SimpleAttributeFormDialogState extends State<SimpleAttributeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    widget.onSubmit(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 320,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              hintText: widget.fieldHint,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Bu maydon majburiy.' : null,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quality form dialog (quality_name + density)
// ─────────────────────────────────────────────────────────────────────────────

class QualityFormDialog extends StatefulWidget {
  const QualityFormDialog({
    super.key,
    this.initialName,
    this.initialDensity,
    required this.onSubmit,
  });

  final String? initialName;
  final int? initialDensity;
  final void Function(BuildContext context, String name, int? density) onSubmit;

  static void show(
    BuildContext context, {
    String? initialName,
    int? initialDensity,
    required void Function(BuildContext context, String name, int? density) onSubmit,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QualityFormDialog(
        initialName: initialName,
        initialDensity: initialDensity,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<QualityFormDialog> createState() => _QualityFormDialogState();
}

class _QualityFormDialogState extends State<QualityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _densityCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _densityCtrl = TextEditingController(
      text: widget.initialDensity != null ? '${widget.initialDensity}' : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _densityCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final density = _densityCtrl.text.trim().isEmpty ? null : int.tryParse(_densityCtrl.text.trim());
    widget.onSubmit(context, _nameCtrl.text.trim(), density);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName != null ? 'Sifatni tahrirlash' : 'Sifat qo\'shish'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Sifat nomi',
                  hintText: 'masalan: Premium',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bu maydon majburiy.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _densityCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Zichlik (ixtiyoriy)',
                  hintText: 'masalan: 1200',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Musbat son kiriting.';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Size form dialog (length + width + product_type_id)
// ─────────────────────────────────────────────────────────────────────────────

class SizeFormDialog extends StatefulWidget {
  const SizeFormDialog({
    super.key,
    this.initialLength,
    this.initialWidth,
    this.initialProductTypeId,
    required this.productTypes,
    required this.onSubmit,
  });

  final int? initialLength;
  final int? initialWidth;
  final int? initialProductTypeId;
  final List<ProductTypeEntity> productTypes;
  final void Function(BuildContext context, int length, int width, int productTypeId) onSubmit;

  static void show(
    BuildContext context, {
    int? initialLength,
    int? initialWidth,
    int? initialProductTypeId,
    required List<ProductTypeEntity> productTypes,
    required void Function(BuildContext context, int length, int width, int productTypeId) onSubmit,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SizeFormDialog(
        initialLength: initialLength,
        initialWidth: initialWidth,
        initialProductTypeId: initialProductTypeId,
        productTypes: productTypes,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<SizeFormDialog> createState() => _SizeFormDialogState();
}

class _SizeFormDialogState extends State<SizeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lengthCtrl;
  late final TextEditingController _widthCtrl;
  int? _selectedTypeId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _lengthCtrl = TextEditingController(
      text: widget.initialLength != null ? '${widget.initialLength}' : '',
    );
    _widthCtrl = TextEditingController(
      text: widget.initialWidth != null ? '${widget.initialWidth}' : '',
    );
    _selectedTypeId = widget.initialProductTypeId;
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeId == null) return;
    setState(() => _submitting = true);
    widget.onSubmit(
      context,
      int.parse(_lengthCtrl.text.trim()),
      int.parse(_widthCtrl.text.trim()),
      _selectedTypeId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialLength != null ? 'O\'lchamni tahrirlash' : 'O\'lcham qo\'shish'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedTypeId,
                decoration: const InputDecoration(labelText: 'Mahsulot turi'),
                items: widget.productTypes
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.type)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTypeId = v),
                validator: (v) => v == null ? 'Tur tanlang.' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lengthCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Uzunlik (sm)'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Majburiy.';
                        if ((int.tryParse(v.trim()) ?? 0) < 1) return 'Musbat son.';
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
                      decoration: const InputDecoration(labelText: 'Kenglik (sm)'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Majburiy.';
                        if ((int.tryParse(v.trim()) ?? 0) < 1) return 'Musbat son.';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Saqlash'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared action status listener
// ─────────────────────────────────────────────────────────────────────────────

/// Call this from BlocListener to handle action status snackbars.
/// Closes the dialog on success.
void handleAttributeActionStatus(BuildContext context, ProductAttributesState state, {VoidCallback? onSuccess}) {
  if (state is! ProductAttributesLoaded) return;
  final status = state.actionStatus;
  final messenger = ScaffoldMessenger.of(context);
  switch (status) {
    case AttributeActionPending():
      break;
    case AttributeActionSuccess(message: final msg):
      Navigator.of(context, rootNavigator: true).maybePop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ));
      onSuccess?.call();
    case AttributeActionFailure(message: final msg):
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ));
    case AttributeActionIdle():
      break;
  }
}
