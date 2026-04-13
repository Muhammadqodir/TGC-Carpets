import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../../core/ui/widgets/desktop_status_bar.dart';
import '../../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../../products/presentation/widgets/product_size_picker_sheet.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../bloc/production_batch_form_bloc.dart';
import '../../bloc/production_batch_form_event.dart';
import '../../bloc/production_batch_form_state.dart';
import '../../widgets/batch_item_row.dart';
import '../../widgets/machine_picker_bottom_sheet.dart';
import '../../widgets/order_picker_bottom_sheet.dart';
import '../../widgets/production_batch_form_controller.dart';

/// Desktop variant of the add/edit production batch form.
class AddProductionBatchDesktopPage extends StatefulWidget {
  const AddProductionBatchDesktopPage({
    super.key,
    required this.controller,
    this.initialBatch,
  });

  final ProductionBatchFormController controller;

  /// When non-null the form is in edit mode.
  final ProductionBatchEntity? initialBatch;

  @override
  State<AddProductionBatchDesktopPage> createState() =>
      _AddProductionBatchDesktopPageState();
}

class _AddProductionBatchDesktopPageState
    extends State<AddProductionBatchDesktopPage> {
  final _formKey = GlobalKey<FormState>();

  ProductionBatchMachine? _selectedMachine;
  DateTime? _plannedDate;
  TimeOfDay? _plannedTime;
  bool get _isEditMode => widget.initialBatch != null;

  ProductionBatchMachine? get _effectiveMachine =>
      _selectedMachine ?? widget.initialBatch?.machine;

  String get _machineDisplay => _effectiveMachine?.name ?? 'Stanok tanlash...';

  bool get _hasMachine => _effectiveMachine != null;

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
      }
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

  String get _formattedPlannedDate {
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
                _isEditMode ? 'Batch yangilandi.' : 'Batch saqlandi.',
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
            backgroundColor: AppColors.background,
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
              actions: [
                BlocBuilder<ProductionBatchFormBloc, ProductionBatchFormState>(
                  builder: (context, state) {
                    if (state is ProductionBatchFormSubmitting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top info bar ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border:
                          Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        // Batch title
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: ctrl.titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Partiya nomi *',
                              hintText: 'Masalan: Sherdoraka | 1 Stanok',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Partiya nomini kiriting'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Machine picker
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: _pickMachine,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.precision_manufacturing_outlined,
                                    size: 16,
                                    color: !_hasMachine
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
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
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedMachine != null)
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedMachine = null),
                                      child: const Icon(Icons.close,
                                          size: 18,
                                          color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Planned date+time picker
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: _plannedDate != null
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: _plannedDate != null ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: _plannedDate != null
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formattedPlannedDate,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: _plannedDate == null
                                            ? AppColors.textSecondary
                                            : null,
                                      ),
                                ),
                                if (_plannedDate != null) ...[
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: _pickTime,
                                    child: const Icon(Icons.access_time,
                                        size: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _plannedDate = null;
                                      _plannedTime = null;
                                    }),
                                    child: const Icon(Icons.close,
                                        size: 16,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Computed type badge (read-only)
                        _ComputedTypeBadge(type: ctrl.computedType),
                      ],
                    ),
                  ),

                  // ── Items section label ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                          child: Text(
                            'Mahsulotlar',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                        child: TextButton.icon(
                          onPressed: () async {
                            final result =
                                await OrderPickerBottomSheet.show(context);
                            if (result != null && mounted) {
                              ctrl.addRowsFromOrder(result.order, result.items);
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Buyurtmadan import'),
                        ),
                      ),
                    ],
                  ),

                  // ── Table header ──────────────────────────────────────────
                  const _DesktopTableHeader(),
                  const Divider(height: 1, color: AppColors.divider),

                  // ── Table rows ────────────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: ctrl.items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final row = ctrl.items[index];
                        return _DesktopItemRow(
                          key: ValueKey(row.id),
                          row: row,
                          allItems: ctrl.items,
                          index: index,
                          onRemove: () => ctrl.removeRow(row),
                          onChanged: () {
                            ctrl.promoteIfSentinel(row);
                            ctrl.updateRow(row);
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),

                  // ── Notes ─────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: TextFormField(
                      controller: ctrl.notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Izoh (ixtiyoriy)',
                        hintText: "Qo'shimcha ma'lumot...",
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),

                  // ── Status bar ────────────────────────────────────────────
                  Builder(builder: (context) {
                    final filled = ctrl.items.where((r) => r.isFilled).toList();
                    final totalQty = filled.fold(
                      0,
                      (sum, r) =>
                          sum + (int.tryParse(r.quantityCtrl.text) ?? 1),
                    );
                    final totalSqm = filled.fold(0.0, (sum, r) {
                      final qty = int.tryParse(r.quantityCtrl.text) ?? 1;
                      if (r.selectedSize != null) {
                        return sum +
                            r.selectedSize!.length *
                                r.selectedSize!.width *
                                qty /
                                10000.0;
                      }
                      if (r.prefilledSizeLength != null &&
                          r.prefilledSizeWidth != null) {
                        return sum +
                            r.prefilledSizeLength! *
                                r.prefilledSizeWidth! *
                                qty /
                                10000.0;
                      }
                      return sum;
                    });
                    return DesktopStatusBar(
                      child: Row(
                        children: [
                          _TotalChip(
                              label: 'Mahsulotlar', value: '${filled.length}'),
                          const SizedBox(width: 16),
                          _TotalChip(label: 'Jami dona', value: '$totalQty'),
                          const SizedBox(width: 16),
                          _TotalChip(
                              label: 'Jami m²',
                              value: '${totalSqm.toStringAsFixed(2)} m²'),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Desktop table header ──────────────────────────────────────────────────────

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          _HeaderCell(label: '#', fixedWidth: 40),
          _HeaderCell(label: 'Mahsulot', flex: 3),
          _HeaderCell(label: 'Rang', flex: 2),
          _HeaderCell(label: 'Tur', flex: 1),
          _HeaderCell(label: 'Sifat', flex: 1),
          _HeaderCell(label: 'O\'lcham', flex: 2),
          _HeaderCell(label: 'Mijoz', fixedWidth: 150),
          _HeaderCell(label: 'Miqdor', fixedWidth: 130),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int? flex;
  final double? fixedWidth;

  const _HeaderCell({required this.label, this.flex, this.fixedWidth});

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
    );
    if (fixedWidth != null) {
      return SizedBox(width: fixedWidth, child: child);
    }
    return Expanded(flex: flex ?? 1, child: child);
  }
}

// ── Desktop item table row ────────────────────────────────────────────────────

class _DesktopItemRow extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _DesktopItemRow({
    super.key,
    required this.row,
    required this.allItems,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isEven = index.isEven;
    return Container(
      color: isEven ? null : AppColors.surface.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // # index
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),

          // Product picker
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _DesktopProductCell(
                row: row,
                allItems: allItems,
                onChanged: onChanged,
              ),
            ),
          ),

          // Color column — entity first, prefill as fallback
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.selectedColor != null
                  ? Row(
                      children: [
                        AppThumbnail(
                          imageUrl: row.selectedColor!.imageUrl,
                          size: 24,
                          borderRadius: 4,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.selectedColor!.colorName,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : row.prefilledColorName != null
                      ? Row(
                          children: [
                            AppThumbnail(
                              imageUrl: row.prefilledColorImageUrl,
                              size: 24,
                              borderRadius: 4,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.prefilledColorName!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '—',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
            ),
          ),

          // Tur column
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.typeName != null
                  ? Text(
                      row.typeName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      '—',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
            ),
          ),

          // Sifat column
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.qualityName != null
                  ? Text(
                      row.qualityName!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      '—',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
            ),
          ),

          // Size column
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: product != null && product.productTypeId != null
                  ? _DesktopSizeCell(
                      row: row,
                      allItems: allItems,
                      productTypeId: product.productTypeId!,
                      onChanged: onChanged,
                    )
                  : row.prefilledProductTypeId != null
                      ? _DesktopSizeCell(
                          row: row,
                          allItems: allItems,
                          productTypeId: row.prefilledProductTypeId!,
                          onChanged: onChanged,
                        )
                      : row.prefilledSizeDimensions != null
                          ? Text(
                              row.prefilledSizeDimensions!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            )
                          : Text(
                              '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
            ),
          ),

          // Source column
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.sourceClientName != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAddToList,
                            strokeWidth: 2,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            row.sourceClientName!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ))
                  : const SizedBox.shrink(),
            ),
          ),

          // Quantity
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CountInput(
                controller: row.quantityCtrl,
                dense: true,
                validator: (v) {
                  if (!row.isFilled) return null;
                  if (v == null || v.trim().isEmpty) return 'Kiriting';
                  if ((int.tryParse(v) ?? 0) < 1) return '≥ 1';
                  return null;
                },
              ),
            ),
          ),

          // Remove action
          SizedBox(
            width: 40,
            child: row.isFilled
                ? IconButton(
                    onPressed: onRemove,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancelCircle,
                      size: 18,
                      strokeWidth: 2.5,
                      color: AppColors.error,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Desktop product picker cell ───────────────────────────────────────────────

class _DesktopProductCell extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final VoidCallback onChanged;

  const _DesktopProductCell({
    required this.row,
    required this.allItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final product = row.selectedProduct;
    final isPrefilled = product == null && row.prefilledColorId != null;
    final displayName = product?.name ?? row.prefilledProductName;
    return InkWell(
      onTap: () async {
        final result = await ProductPickerBottomSheet.show(context);
        if (result != null) {
          row.selectedProduct = result.product;
          row.selectedColor = result.color;
          row.selectedSize = null;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: (product == null && !isPrefilled)
                ? AppColors.divider
                : AppColors.primary,
            width: (product == null && !isPrefilled) ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: (product != null || isPrefilled)
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              displayName == null
                  ? Icons.search_rounded
                  : Icons.inventory_2_outlined,
              size: 14,
              color: displayName == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayName ?? 'Mahsulot tanlash',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: displayName == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (displayName != null)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedReplace,
                size: 14,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Desktop size picker cell ──────────────────────────────────────────────────

class _DesktopSizeCell extends StatelessWidget {
  final BatchItemRow row;
  final List<BatchItemRow> allItems;
  final int productTypeId;
  final VoidCallback onChanged;

  const _DesktopSizeCell({
    required this.row,
    required this.allItems,
    required this.productTypeId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final size = row.selectedSize;
    final displayDimensions = size?.dimensions ?? row.prefilledSizeDimensions;
    return InkWell(
      onTap: () async {
        final picked = await ProductSizePickerSheet.show(
          context,
          productTypeId: productTypeId,
        );
        if (picked != null) {
          final effectiveColorId =
              row.selectedColor?.id ?? row.prefilledColorId;
          final isDuplicate = allItems.any((r) {
            if (r.id == row.id) return false;
            final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
            final rSizeId = r.selectedSize?.id ?? r.prefilledSizeId;
            return rColorId == effectiveColorId && rSizeId == picked.id;
          });
          if (isDuplicate) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Bu mahsulot varianti allaqachon qo'shilgan."),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
          row.selectedSize = picked;
          onChanged();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: displayDimensions == null
                ? AppColors.divider
                : AppColors.primary,
            width: displayDimensions == null ? 1 : 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: displayDimensions != null
              ? AppColors.primary.withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              size: 14,
              color: displayDimensions == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayDimensions ?? "O'lcham",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: displayDimensions == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight:
                          displayDimensions != null ? FontWeight.w600 : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: displayDimensions == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Total chip ────────────────────────────────────────────────────────────────

// ── Computed type badge (read-only indicator) ─────────────────────────────────

class _ComputedTypeBadge extends StatelessWidget {
  final String type;
  const _ComputedTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'by_order'  => ('Buyurtma bo\'yicha', AppColors.primary),
      'for_stock' => ('Ombor uchun', AppColors.accent),
      _           => ('Aralash', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Total chip ────────────────────────────────────────────────────────────────

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;

  const _TotalChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
