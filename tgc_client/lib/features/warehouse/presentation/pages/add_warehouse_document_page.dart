import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/presentation/widget/product_picker_bottom_sheet.dart';
import '../../../products/presentation/widget/product_size_picker_sheet.dart';
import '../bloc/warehouse_form_bloc.dart';
import '../bloc/warehouse_form_event.dart';
import '../bloc/warehouse_form_state.dart';

class AddWarehouseDocumentPage extends StatelessWidget {
  const AddWarehouseDocumentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WarehouseFormBloc>(),
      child: const _AddWarehouseDocumentView(),
    );
  }
}

class _AddWarehouseDocumentView extends StatefulWidget {
  const _AddWarehouseDocumentView();

  @override
  State<_AddWarehouseDocumentView> createState() =>
      _AddWarehouseDocumentViewState();
}

class _AddWarehouseDocumentViewState extends State<_AddWarehouseDocumentView> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  final _notesCtrl = TextEditingController();
  final List<_ItemRow> _items = [];

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  void _addItem() => setState(() => _items.add(_ItemRow()));

  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final hasUnpickedProduct = _items.any((r) => r.selectedProduct == null);
    if (hasUnpickedProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha qatorlardagi mahsulotni tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final items = _items
        .map((row) => {
              'product_id': row.selectedProduct!.id,
              if (row.selectedSize != null)
                'product_size_id': row.selectedSize!.id,
              'quantity': int.parse(row.quantityCtrl.text.trim()),
              if (row.notesCtrl.text.trim().isNotEmpty)
                'notes': row.notesCtrl.text.trim(),
            })
        .toList();

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    context.read<WarehouseFormBloc>().add(
          WarehouseFormSubmitted(
            type: 'in',
            documentDate: dateStr,
            items: items,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WarehouseFormBloc, WarehouseFormState>(
      listener: (context, state) {
        if (state is WarehouseFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kirim hujjati muvaffaqiyatli yaratildi!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        } else if (state is WarehouseFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kirim hujjati'),
          leading: IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              strokeWidth: 2,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Header info ──────────────────────────────────────
                    const _SectionHeader(title: 'Hujjat ma\'lumotlari'),
                    const SizedBox(height: 12),

                    // Date picker
                    _DatePickerField(
                      date: _selectedDate,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Izoh (ixtiyoriy)',
                        hintText: 'Qo\'shimcha ma\'lumot...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Items ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _SectionHeader(title: 'Mahsulotlar'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      return _ItemFormRow(
                        key: ValueKey(row.id),
                        row: row,
                        index: index,
                        onRemove: () => _removeItem(index),
                        canRemove: _items.length > 1,
                        onProductChanged: () => setState(() {}),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Qo\'shish'),
                    ),

                    const SizedBox(height: 64),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                top: false,
                child: BlocBuilder<WarehouseFormBloc, WarehouseFormState>(
                  builder: (context, state) {
                    final isLoading = state is WarehouseFormSubmitting;
                    return FilledButton(
                      onPressed: isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Saqlash'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Domain model for each item row ──────────────────────────────────────────

class _ItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductSizeEntity? selectedSize;
  final quantityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  void dispose() {
    quantityCtrl.dispose();
    notesCtrl.dispose();
  }
}

// ── Item form row widget ─────────────────────────────────────────────────────

class _ItemFormRow extends StatelessWidget {
  final _ItemRow row;
  final int index;
  final VoidCallback onRemove;
  final bool canRemove;
  final VoidCallback onProductChanged;

  const _ItemFormRow({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
    required this.canRemove,
    required this.onProductChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row header
            Row(
              children: [
                Text('${index + 1}-mahsulot',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                if (canRemove) ...[
                  InkWell(
                    onTap: onRemove,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        size: 18,
                        strokeWidth: 2.5,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                ]
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: // Product picker button
                      InkWell(
                    onTap: () async {
                      final picked =
                          await ProductPickerBottomSheet.show(context);
                      if (picked != null) {
                        row.selectedProduct = picked;
                        row.selectedSize = null; // reset size when product changes
                        onProductChanged();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: product == null
                              ? AppColors.divider
                              : AppColors.primary,
                          width: product == null ? 1 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: product != null
                            ? AppColors.primary.withValues(alpha: 0.05)
                            : null,
                      ),
                      child: product == null
                          ? Row(
                              children: [
                                const Icon(Icons.search_rounded,
                                    size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Mahsulot tanlash',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${product.productType?.type ?? ''} • ${product.color}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                const HugeIcon(
                                    icon: HugeIcons.strokeRoundedReplace,
                                    size: 18,
                                    color: AppColors.primary),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Quantity
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: row.quantityCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Miqdor *',
                      isDense: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Miqdorni kiriting';
                      }
                      final qty = int.tryParse(value);
                      if (qty == null || qty < 1) {
                        return 'Kamida 1 bo\'lishi kerak';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            // Size picker — shown only when product with a type is selected
            if (product != null && product.productTypeId != null) ...[
              const SizedBox(height: 8),
              _SizePicker(
                row: row,
                productTypeId: product.productTypeId!,
                onChanged: onProductChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline size chip selector within an item row.
class _SizePicker extends StatelessWidget {
  final _ItemRow row;
  final int productTypeId;
  final VoidCallback onChanged;

  const _SizePicker({
    required this.row,
    required this.productTypeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = row.selectedSize;
    return InkWell(
      onTap: () async {
        final picked = await ProductSizePickerSheet.show(
          context,
          productTypeId: productTypeId,
        );
        if (picked != null) {
          row.selectedSize = picked;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: size == null ? AppColors.divider : AppColors.primary,
            width: size == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: size != null ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 16,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                size == null ? 'O\'lcham tanlash' : size.dimensions,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: size == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: size != null ? FontWeight.w600 : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: size == null ? AppColors.textSecondary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({required this.date, required this.onTap});

  String get _formatted =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              _formatted,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
