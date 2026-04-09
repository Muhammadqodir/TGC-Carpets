import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../clients/presentation/widget/client_picker_bottom_sheet.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../products/presentation/widget/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widget/product_size_picker_sheet.dart';
import '../../bloc/order_form_bloc.dart';
import '../../bloc/order_form_event.dart';
import '../../bloc/order_form_state.dart';
import '../../widget/order_item_row.dart';

/// Mobile variant of the "add order" form.
class AddOrderMobilePage extends StatefulWidget {
  const AddOrderMobilePage({super.key});

  @override
  State<AddOrderMobilePage> createState() => _AddOrderMobilePageState();
}

class _AddOrderMobilePageState extends State<AddOrderMobilePage> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  ClientEntity? _selectedClient;
  DateTime _orderDate = DateTime.now();
  String _status = 'pending';
  final List<OrderItemRow> _rows = [OrderItemRow()];

  static const _statuses = [
    (label: 'Kutilmoqda', value: 'pending'),
    (label: 'Tasdiqlangan', value: 'confirmed'),
    (label: 'Bekor qilindi', value: 'cancelled'),
    (label: 'Yetkazildi', value: 'delivered'),
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(OrderItemRow()));
  }

  void _removeRow(OrderItemRow row) {
    if (_rows.length == 1) return;
    setState(() {
      row.dispose();
      _rows.remove(row);
    });
  }

  Future<void> _pickProduct(OrderItemRow row) async {
    final result = await ProductPickerBottomSheet.show(context);
    if (result == null) return;

    setState(() {
      row.selectedProduct = result.product;
      row.selectedColor = result.color;
      row.selectedSize = null;
    });

    // Auto-pick size if product has a type
    if (result.product.productTypeId != null && context.mounted) {
      final size = await ProductSizePickerSheet.show(
        context,
        productTypeId: result.product.productTypeId!,
      );
      if (size != null && mounted) {
        setState(() => row.selectedSize = size);
      }
    }
  }

  Future<void> _pickClient() async {
    final client = await ClientPickerBottomSheet.show(context);
    if (client != null && mounted) {
      setState(() => _selectedClient = client);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _orderDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final filledRows = _rows.where((r) => r.isFilled).toList();
    if (filledRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta mahsulot qo\'shing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final items = filledRows
        .map((r) => {
              'product_color_id': r.selectedColor!.id,
              if (r.selectedSize != null) 'product_size_id': r.selectedSize!.id,
              'quantity': int.tryParse(r.quantityCtrl.text.trim()) ?? 1,
            })
        .toList();

    final dateStr =
        '${_orderDate.year}-${_orderDate.month.toString().padLeft(2, '0')}-${_orderDate.day.toString().padLeft(2, '0')}';

    context.read<OrderFormBloc>().add(OrderFormSubmitted(
          orderDate: dateStr,
          items: items,
          clientId: _selectedClient?.id,
          status: _status,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrderFormBloc, OrderFormState>(
      listener: (context, state) {
        if (state is OrderFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Buyurtma saqlandi.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        } else if (state is OrderFormFailure) {
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
          title: const Text('Yangi buyurtma'),
          titleSpacing: 0,
          leading: IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              strokeWidth: 2,
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            BlocBuilder<OrderFormBloc, OrderFormState>(
              builder: (context, state) {
                if (state is OrderFormSubmitting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return TextButton(
                  onPressed: _submit,
                  child: const Text('Saqlash'),
                );
              },
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Date ─────────────────────────────────────────────────────
              _SectionLabel(label: 'Sana'),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        '${_orderDate.day.toString().padLeft(2, '0')}.${_orderDate.month.toString().padLeft(2, '0')}.${_orderDate.year}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Status ───────────────────────────────────────────────────
              _SectionLabel(label: 'Holat'),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _statuses
                    .map((s) =>
                        DropdownMenuItem(value: s.value, child: Text(s.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 16),

              // ── Client ───────────────────────────────────────────────────
              _SectionLabel(label: 'Mijoz (ixtiyoriy)'),
              InkWell(
                onTap: _pickClient,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedClient?.shopName ?? 'Mijoz tanlash...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _selectedClient == null
                                    ? AppColors.textSecondary
                                    : null,
                              ),
                        ),
                      ),
                      if (_selectedClient != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedClient = null),
                          child: const Icon(Icons.close,
                              size: 18, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Items ─────────────────────────────────────────────────────
              _SectionLabel(label: 'Mahsulotlar'),
              ...List.generate(_rows.length, (i) {
                final row = _rows[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OrderItemRowWidget(
                    row: row,
                    onPickProduct: () => _pickProduct(row),
                    onRemove: _rows.length > 1 ? () => _removeRow(row) : null,
                    onQuantityChanged: () => setState(() {}),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Qator qo\'shish'),
              ),
              const SizedBox(height: 16),

              // ── Notes ────────────────────────────────────────────────────
              _SectionLabel(label: 'Izoh (ixtiyoriy)'),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Qo\'shimcha ma\'lumot...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _OrderItemRowWidget extends StatelessWidget {
  final OrderItemRow row;
  final VoidCallback onPickProduct;
  final VoidCallback? onRemove;
  final VoidCallback onQuantityChanged;

  const _OrderItemRowWidget({
    required this.row,
    required this.onPickProduct,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPickProduct,
                  child: Text(
                    row.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: row.isFilled
                              ? AppColors.textPrimary
                              : AppColors.primary,
                          decoration:
                              row.isFilled ? null : TextDecoration.underline,
                        ),
                  ),
                ),
              ),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close,
                      size: 18, color: AppColors.textSecondary),
                ),
            ],
          ),
          if (row.isFilled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Miqdor: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: row.quantityCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    onChanged: (_) => onQuantityChanged(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kerak';
                      final n = int.tryParse(v);
                      if (n == null || n < 1) return '≥1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
