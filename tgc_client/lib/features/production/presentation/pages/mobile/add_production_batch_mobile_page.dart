import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/size_input_sheet.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../bloc/production_batch_form_bloc.dart';
import '../../bloc/production_batch_form_event.dart';
import '../../bloc/production_batch_form_state.dart';
import '../../widgets/batch_item_row.dart';
import '../../widgets/machine_picker_bottom_sheet.dart';
import '../../widgets/order_picker_bottom_sheet.dart';
import '../../widgets/production_batch_form_controller.dart';

/// Mobile variant of the add/edit production batch form.
class AddProductionBatchMobilePage extends StatefulWidget {
  const AddProductionBatchMobilePage({
    super.key,
    required this.controller,
    this.initialBatch,
  });

  final ProductionBatchFormController controller;

  /// When non-null the form is in edit mode.
  final ProductionBatchEntity? initialBatch;

  @override
  State<AddProductionBatchMobilePage> createState() =>
      _AddProductionBatchMobilePageState();
}

class _AddProductionBatchMobilePageState
    extends State<AddProductionBatchMobilePage> {
  final _formKey = GlobalKey<FormState>();

  ProductionBatchMachine? _selectedMachine;
  DateTime? _plannedDate;
  TimeOfDay? _plannedTime;
  bool get _isEditMode => widget.initialBatch != null;

  ProductionBatchMachine? get _effectiveMachine =>
      _selectedMachine ?? widget.initialBatch?.machine;

  bool get _hasMachine => _effectiveMachine != null;

  String get _machineDisplay => _effectiveMachine?.name ?? 'Stanok tanlash...';

  @override
  void initState() {
    super.initState();
    final batch = widget.initialBatch;
    if (batch != null) {
      widget.controller.titleCtrl.text = batch.batchTitle;
      widget.controller.notesCtrl.text = batch.notes ?? '';
      if (batch.plannedDatetime != null) {
        _plannedDate = batch.plannedDatetime;
        _plannedTime = TimeOfDay.fromDateTime(batch.plannedDatetime!);
      } else {
        _plannedDate = DateTime.now();
      }
    } else {
      _plannedDate = DateTime.now();
    }
  }

  Future<void> _pickMachine() async {
    final machine = await MachinePickerBottomSheet.show(context);
    if (machine != null && mounted) setState(() => _selectedMachine = machine);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _plannedDate = picked);
  }

  Future<void> _pickTime() async {
    if (_plannedDate == null) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _plannedTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _plannedTime = picked);
  }

  String? get _plannedDateStr {
    if (_plannedDate == null) return null;
    final d = _plannedDate!;
    final t = _plannedTime;
    if (t != null) {
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T00:00:00';
  }

  String get _formattedDate {
    if (_plannedDate == null) return 'Reja sana (ixtiyoriy)';
    final d = _plannedDate!;
    final t = _plannedTime;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    if (t != null) {
      return '$dateStr ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return dateStr;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasMachine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stanokni tanlash shart.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final ctrl = widget.controller;
    final title = ctrl.titleCtrl.text.trim();
    final notes =
        ctrl.notesCtrl.text.trim().isEmpty ? null : ctrl.notesCtrl.text.trim();
    final items = ctrl.buildItemsPayload();

    if (_isEditMode) {
      context.read<ProductionBatchFormBloc>().add(
            ProductionBatchFormUpdateSubmitted(
              batchId: widget.initialBatch!.id,
              batchTitle: title,
              machineId: _effectiveMachine!.id,
              plannedDatetime: _plannedDateStr,
              type: ctrl.computedType,
              notes: notes,
              items: items.isEmpty ? null : items,
            ),
          );
    } else {
      context.read<ProductionBatchFormBloc>().add(
            ProductionBatchFormSubmitted(
              batchTitle: title,
              machineId: _effectiveMachine!.id,
              plannedDatetime: _plannedDateStr,
              type: ctrl.computedType,
              notes: notes,
              items: items.isEmpty ? null : items,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductionBatchFormBloc, ProductionBatchFormState>(
      listener: (context, state) {
        if (state is ProductionBatchFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode ? 'Partiya yangilandi.' : 'Partiya saqlandi.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        } else if (state is ProductionBatchFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                _isEditMode
                    ? '#${widget.initialBatch!.id} Tahrirlash'
                    : 'Yangi ishlab chiqarish',
              ),
              titleSpacing: 0,
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
                        _SectionHeader(
                          title: _isEditMode
                              ? 'Batch ma\'lumotlari'
                              : 'Batch ma\'lumotlari',
                        ),
                        const SizedBox(height: 12),

                        // Batch title
                        TextFormField(
                          controller: ctrl.titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Batch nomi *',
                            hintText: 'Masalan: Batch #1',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Batch nomini kiriting'
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Machine picker
                        InkWell(
                          onTap: _pickMachine,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: !_hasMachine
                                    ? AppColors.divider
                                    : AppColors.primary,
                                width: !_hasMachine ? 1.0 : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _hasMachine
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.precision_manufacturing_outlined,
                                  size: 18,
                                  color: !_hasMachine
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _machineDisplay,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: !_hasMachine
                                              ? AppColors.textSecondary
                                              : null,
                                        ),
                                  ),
                                ),
                                if (_selectedMachine != null)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedMachine = null),
                                    child: const Icon(Icons.close,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Planned date
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _plannedDate != null
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: _plannedDate != null ? 1.5 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: _plannedDate != null
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formattedDate,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: _plannedDate == null
                                              ? AppColors.textSecondary
                                              : null,
                                        ),
                                  ),
                                ),
                                if (_plannedDate != null) ...[
                                  GestureDetector(
                                    onTap: _pickTime,
                                    child: const Icon(Icons.access_time,
                                        size: 18, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _plannedDate = null;
                                      _plannedTime = null;
                                    }),
                                    child: const Icon(Icons.close,
                                        size: 18,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notes
                        _ComputedTypeRow(type: ctrl.computedType),
                        const SizedBox(height: 12),

                        // Notes
                        TextFormField(
                          controller: ctrl.notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Izoh (ixtiyoriy)',
                            hintText: "Qo'shimcha ma'lumot...",
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Items header + import button
                        Row(
                          children: [
                            const Expanded(
                              child: _SectionHeader(title: 'Mahsulotlar'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final result =
                                    await OrderPickerBottomSheet.show(context);
                                if (result != null && context.mounted) {
                                  ctrl.addRowsFromOrder(
                                      result.order, result.items);
                                }
                              },
                              icon:
                                  const Icon(Icons.download_rounded, size: 14),
                              label: const Text('Import'),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ...ctrl.items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return _MobileItemCard(
                            key: ValueKey(row.id),
                            row: row,
                            allItems: ctrl.items,
                            index: index,
                            onRemove: () => ctrl.removeRow(row),
                            canRemove: row.isFilled,
                            onProductChanged: () {
                              ctrl.promoteIfSentinel(row);
                              ctrl.updateRow(row);
                            },
                          );
                        }),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // Submit button
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    top: false,
                    child: BlocBuilder<ProductionBatchFormBloc,
                        ProductionBatchFormState>(
                      builder: (context, state) {
                        if (state is ProductionBatchFormSubmitting) {
                          return FilledButton(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50)),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50)),
                          child: const Text('Saqlash'),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _ComputedTypeRow extends StatelessWidget {
  final String type;
  const _ComputedTypeRow({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'by_order' => ('Buyurtma bo\'yicha', AppColors.primary),
      'for_stock' => ('Ombor uchun', AppColors.accent),
      _ => ('Aralash', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'Tur: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
          const Spacer(),
          Text(
            'Avtomatik',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
    );
  }
}

// ── Mobile item card ──────────────────────────────────────────────────────────

class _MobileItemCard extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final bool canRemove;
  final VoidCallback onProductChanged;

  const _MobileItemCard({
    super.key,
    required this.row,
    required this.allItems,
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
            Row(
              children: [
                Text('${index + 1}-mahsulot',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 8),
                if (row.sourceOrderId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedStore03,
                              size: 11,
                              strokeWidth: 3,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              row.sourceClientName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall!.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (canRemove) ...[
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
                  const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ProductPickerButton(
                    row: row,
                    allItems: allItems,
                    onChanged: onProductChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: (product != null && product.productTypeId != null)
                      ? _SizePicker(
                          row: row,
                          allItems: allItems,
                          productTypeId: product.productTypeId!,
                          onChanged: onProductChanged,
                        )
                      : (product == null && row.prefilledProductTypeId != null)
                          ? _SizePicker(
                              row: row,
                              allItems: allItems,
                              productTypeId: row.prefilledProductTypeId!,
                              onChanged: onProductChanged,
                            )
                          : const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: CountInput(
                    controller: row.quantityCtrl,
                    validator: (v) {
                      if (row.selectedProduct == null) return null;
                      if (v == null || v.trim().isEmpty) {
                        return 'Miqdorni kiriting';
                      }
                      final qty = int.tryParse(v);
                      if (qty == null || qty < 1) return 'Kamida 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product picker button ─────────────────────────────────────────────────────

class _ProductPickerButton extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final VoidCallback onChanged;

  const _ProductPickerButton({
    required this.row,
    required this.allItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isPrefilled = product == null && row.prefilledColorId != null;
    return InkWell(
      onTap: () async {
        final result = await ProductPickerBottomSheet.show(context);
        if (result != null) {
          row.selectedProduct = result.product;
          row.selectedColor = result.color;
          row.selectedLength = null;
          row.selectedWidth = null;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: (!isPrefilled && product == null)
                ? AppColors.divider
                : AppColors.primary,
            width: (!isPrefilled && product == null) ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: (product != null || isPrefilled)
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: (!isPrefilled && product == null)
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
                  AppThumbnail(
                    imageUrl: row.selectedColor?.imageUrl ??
                        row.prefilledColorImageUrl,
                    size: 28,
                    borderRadius: 4,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product?.name ?? row.prefilledProductName ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Builder(builder: (context) {
                          final parts = [
                            if (row.typeName != null) row.typeName!,
                            if (row.qualityName != null) row.qualityName!,
                            if ((row.selectedColor?.colorName ??
                                    row.prefilledColorName) !=
                                null)
                              row.selectedColor?.colorName.toUpperCase() ??
                                  row.prefilledColorName!.toUpperCase(),
                          ];
                          if (parts.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                parts.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedReplace,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Size picker ───────────────────────────────────────────────────────────────

class _SizePicker extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _SizePicker({
    required this.row,
    required this.allItems,
    required this.productTypeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayDimensions = row.sizeDimensions;
    final hasSize = displayDimensions != null;
    return InkWell(
      onTap: () async {
        final picked = await SizeInputSheet.show(
          context,
          initialLength: row.effectiveLength,
          initialWidth: row.effectiveWidth,
        );
        if (picked != null) {
          final isDuplicate = allItems.any(
            (r) =>
                r.id != row.id &&
                (r.selectedColor?.id ?? r.prefilledColorId) ==
                    (row.selectedColor?.id ?? row.prefilledColorId) &&
                r.effectiveLength == picked.length &&
                r.effectiveWidth == picked.width,
          );
          if (isDuplicate) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bu mahsulot varianti allaqachon qo\'shilgan.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
          row.selectedLength = picked.length;
          row.selectedWidth = picked.width;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: !hasSize ? AppColors.divider : AppColors.primary,
            width: !hasSize ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
          color: hasSize ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 16,
              color: !hasSize ? AppColors.textSecondary : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayDimensions ?? "O'lcham tanlash",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: !hasSize
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: hasSize ? FontWeight.w600 : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: !hasSize ? AppColors.textSecondary : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
