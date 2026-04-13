import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/extensions/amount.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/widgets/client_picker_bottom_sheet.dart';
import 'package:tgc_client/features/products/domain/entities/product_color_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_picker_bottom_sheet.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_size_picker_sheet.dart';
import 'package:tgc_client/core/ui/widgets/count_input.dart';
import 'package:tgc_client/features/sales/presentation/bloc/sale_form_bloc.dart';
import 'package:tgc_client/features/sales/presentation/bloc/sale_form_event.dart';
import 'package:tgc_client/features/sales/presentation/bloc/sale_form_state.dart';

class AddSalePage extends StatelessWidget {
  const AddSalePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SaleFormBloc>(),
      child: const _AddSaleView(),
    );
  }
}

class _AddSaleView extends StatefulWidget {
  const _AddSaleView();

  @override
  State<_AddSaleView> createState() => _AddSaleViewState();
}

class _AddSaleViewState extends State<_AddSaleView> {
  final _formKey = GlobalKey<FormState>();

  ClientEntity? _selectedClient;
  DateTime _selectedDate = DateTime.now();
  final _notesCtrl = TextEditingController();
  final List<_SaleItemRow> _items = [];

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  void _addItem() => setState(() => _items.add(_SaleItemRow()));

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

  double get _totalAmount => _items.fold(0.0, (sum, row) {
        final qty = int.tryParse(row.quantityCtrl.text) ?? 0;
        final price = double.tryParse(row.priceCtrl.text) ?? 0.0;
        return sum + (qty * price);
      });
  double get _totalQuantity => _items.fold(0.0, (sum, row) {
        final qty = int.tryParse(row.quantityCtrl.text) ?? 0;
        return sum + qty;
      });

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
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, mijozni tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

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
              if (row.selectedColor != null)
                'product_color_id': row.selectedColor!.id,
              if (row.selectedSize != null)
                'product_size_id': row.selectedSize!.id,
              'quantity': int.parse(row.quantityCtrl.text.trim()),
              'price': double.parse(row.priceCtrl.text.trim()),
            })
        .toList();

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    context.read<SaleFormBloc>().add(
          SaleFormSubmitted(
            clientId: _selectedClient!.id,
            saleDate: dateStr,
            items: items,
            notes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SaleFormBloc, SaleFormState>(
      listener: (context, state) {
        if (state is SaleFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sotuv muvaffaqiyatli saqlandi!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        } else if (state is SaleFormFailure) {
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
          title: const Text('Sotuv qo\'shish'),
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
                    // ── Client & date ─────────────────────────────────────
                    const _SectionHeader(title: 'Asosiy ma\'lumotlar'),
                    const SizedBox(height: 12),

                    // Client picker
                    _ClientPickerField(
                      selected: _selectedClient,
                      onTap: () async {
                        final picked =
                            await ClientPickerBottomSheet.show(context);
                        if (picked != null) {
                          setState(() => _selectedClient = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Date picker
                    _DatePickerField(
                      date: _selectedDate,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),

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

                    // ── Items ─────────────────────────────────────────────
                    const _SectionHeader(title: 'Mahsulotlar'),
                    const SizedBox(height: 8),

                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      return _SaleItemFormRow(
                        key: ValueKey(row.id),
                        row: row,
                        index: index,
                        onRemove: () => _removeItem(index),
                        canRemove: _items.length > 1,
                        onChanged: () => setState(() {}),
                      );
                    }),

                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Mahsulot qo\'shish'),
                    ),

                    const SizedBox(height: 12),

                    // ── Total ─────────────────────────────────────────────
                    _TotalRow(
                      total: _totalAmount,
                      totalQuantity: _totalQuantity,
                    ),

                    const SizedBox(height: 72),
                  ],
                ),
              ),
            ),

            // Save button pinned at bottom
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                top: false,
                child: BlocBuilder<SaleFormBloc, SaleFormState>(
                  builder: (context, state) {
                    final isLoading = state is SaleFormSubmitting;
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

// ── Sale item row domain model ───────────────────────────────────────────────

class _SaleItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductColorEntity? selectedColor;
  ProductSizeEntity? selectedSize;
  final quantityCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  double get subtotal {
    final qty = int.tryParse(quantityCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0.0;
    return qty * price;
  }

  void dispose() {
    quantityCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── Sale item form row widget ────────────────────────────────────────────────

class _SaleItemFormRow extends StatelessWidget {
  final _SaleItemRow row;
  final int index;
  final VoidCallback onRemove;
  final bool canRemove;
  final VoidCallback onChanged;

  const _SaleItemFormRow({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
    required this.canRemove,
    required this.onChanged,
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
            Row(
              children: [
                Text(
                  '${index + 1}-mahsulot',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                if (canRemove)
                  InkWell(
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancelCircle,
                        size: 18,
                        strokeWidth: 2.5,
                        color: AppColors.error,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Product picker
            InkWell(
              onTap: () async {
                final result = await ProductPickerBottomSheet.show(context);
                if (result != null) {
                  row.selectedProduct = result.product;
                  row.selectedColor = result.color;
                  row.selectedSize = null; // reset size when product changes
                  onChanged();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color:
                        product == null ? AppColors.divider : AppColors.primary,
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
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  product.name,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  [
                                    if (product.productType?.type != null)
                                      product.productType!.type,
                                    if (row.selectedColor != null)
                                      row.selectedColor!.colorName,
                                  ].join(' · '),
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
            // Size picker — shown when the product has a known type
            if (product != null && product.productTypeId != null) ...[
              const SizedBox(height: 8),
              _SaleSizePicker(
                row: row,
                productTypeId: product.productTypeId!,
                onChanged: onChanged,
              ),
            ],
            const SizedBox(height: 8),

            // Quantity + Price
            Row(
              children: [
                Expanded(
                  child: CountInput(
                    controller: row.quantityCtrl,
                    onChanged: onChanged,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Majburiy';
                      if ((int.tryParse(v) ?? 0) < 1) return '≥ 1';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: row.priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Narx(\$) *',
                      isDense: true,
                    ),
                    onChanged: (_) => onChanged(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Majburiy';
                      if ((double.tryParse(v) ?? -1) < 0) return '≥ 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            if (row.subtotal > 0) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Jami: \$ ${row.subtotal.toCurrencyString()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sale-specific inline size picker ────────────────────────────────────────

class _SaleSizePicker extends StatelessWidget {
  final _SaleItemRow row;
  final int productTypeId;
  final VoidCallback onChanged;

  const _SaleSizePicker({
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
          color:
              size != null ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 16,
              color:
                  size == null ? AppColors.textSecondary : AppColors.primary,
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
              color:
                  size == null ? AppColors.textSecondary : AppColors.primary,
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

class _ClientPickerField extends StatelessWidget {
  final ClientEntity? selected;
  final VoidCallback onTap;

  const _ClientPickerField({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected == null ? AppColors.divider : AppColors.primary,
            width: selected == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected != null
              ? AppColors.primary.withValues(alpha: 0.04)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 18,
              color: selected != null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: selected == null
                  ? Text(
                      'Mijoz tanlash *',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          selected!.shopName,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          selected!.phone,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
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
            Text(_formatted, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final double total;
  final double totalQuantity;

  const _TotalRow({required this.total, required this.totalQuantity});

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Umumiy mahsulotlar soni',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                Text(
                  '${totalQuantity.toCurrencyString()} ta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Umumiy summa',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                Text(
                  '\$ ${total.toCurrencyString()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ));
  }
}
