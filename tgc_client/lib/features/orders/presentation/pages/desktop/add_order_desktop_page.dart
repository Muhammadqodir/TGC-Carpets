import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../clients/presentation/widget/client_picker_bottom_sheet.dart';
import '../../../../products/presentation/widget/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widget/product_size_picker_sheet.dart';
import '../../bloc/order_form_bloc.dart';
import '../../bloc/order_form_event.dart';
import '../../bloc/order_form_state.dart';
import '../../widget/order_item_row.dart';

/// Desktop variant of the "add order" form.
class AddOrderDesktopPage extends StatefulWidget {
  const AddOrderDesktopPage({super.key});

  @override
  State<AddOrderDesktopPage> createState() => _AddOrderDesktopPageState();
}

class _AddOrderDesktopPageState extends State<AddOrderDesktopPage> {
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

  void _addRow() => setState(() => _rows.add(OrderItemRow()));

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
    if (client != null && mounted) setState(() => _selectedClient = client);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _orderDate = picked);
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Yangi buyurtma'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            BlocBuilder<OrderFormBloc, OrderFormState>(
              builder: (context, state) {
                if (state is OrderFormSubmitting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                }
                return FilledButton(
                  onPressed: _submit,
                  child: const Text('Saqlash'),
                );
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left panel: header fields ─────────────────────────────────
              SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: 'Sana'),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
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
                      _FieldLabel(label: 'Holat'),
                      DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        items: _statuses
                            .map((s) => DropdownMenuItem(
                                value: s.value, child: Text(s.label)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel(label: 'Mijoz (ixtiyoriy)'),
                      InkWell(
                        onTap: _pickClient,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
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
                                  _selectedClient?.shopName ??
                                      'Mijoz tanlash...',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: _selectedClient == null
                                            ? AppColors.textSecondary
                                            : null,
                                      ),
                                ),
                              ),
                              if (_selectedClient != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedClient = null),
                                  child: const Icon(Icons.close,
                                      size: 18,
                                      color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel(label: 'Izoh (ixtiyoriy)'),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Qo\'shimcha ma\'lumot...',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Divider ───────────────────────────────────────────────────
              const VerticalDivider(width: 1),

              // ── Right panel: items table ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table header
                    Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
                              flex: 4,
                              child: Text('Mahsulot',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontSize: 12))),
                          const SizedBox(
                              width: 100,
                              child: Text('Miqdor',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      fontSize: 12))),
                          const SizedBox(width: 40),
                          TextButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Qo\'shish'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: GestureDetector(
                                    onTap: () => _pickProduct(row),
                                    child: Text(
                                      row.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: row.isFilled
                                                ? AppColors.textPrimary
                                                : AppColors.primary,
                                            decoration: row.isFilled
                                                ? null
                                                : TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    controller: row.quantityCtrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Kerak';
                                      }
                                      final n = int.tryParse(v);
                                      if (n == null || n < 1) return '≥1';
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: _rows.length > 1
                                      ? IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18,
                                              color: AppColors.error),
                                          onPressed: () => _removeRow(row),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

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
