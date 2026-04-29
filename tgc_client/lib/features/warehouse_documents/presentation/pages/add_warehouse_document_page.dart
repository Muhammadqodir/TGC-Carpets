import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/desktop_status_bar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/services/warehouse_document_draft_service.dart';
import '../widgets/production_batch_picker_bottom_sheet.dart';
import '../widgets/warehouse_document_form_controller.dart';
import '../widgets/warehouse_document_form_item_row.dart';
import '../widgets/warehouse_document_form_table_header.dart';
import 'args/warehouse_document_preview_args.dart';

/// Add warehouse document page.
/// Owns the form controller and manages draft auto-save/restore.
class AddWarehouseDocumentPage extends StatefulWidget {
  const AddWarehouseDocumentPage({super.key});

  @override
  State<AddWarehouseDocumentPage> createState() =>
      _AddWarehouseDocumentPageState();
}

class _AddWarehouseDocumentPageState extends State<AddWarehouseDocumentPage> {
  late final WarehouseDocumentFormController _ctrl;
  late final WarehouseDocumentDraftService _draft;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WarehouseDocumentFormController();
    _ctrl.addListener(_onControllerChanged);
    _init();
  }

  Future<void> _init() async {
    final authState = sl<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _ctrl.username = authState.user.name;
    }

    final prefs = await SharedPreferences.getInstance();
    _draft = WarehouseDocumentDraftService(prefs);
    await _draft.restore(_ctrl);

    if (mounted) setState(() => _ready = true);
  }

  void _onControllerChanged() {
    if (_ready) _draft.save(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope<bool?>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) return;
        if (result == true) {
          _draft.clear();
        }
      },
      child: _AddWarehouseDocumentForm(controller: _ctrl),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Form implementation
// ══════════════════════════════════════════════════════════════════════════════

/// Desktop variant of the "add warehouse document" form.
/// Displays items as an editable table that mirrors the production batch form
/// structure. Supports both manual entry and import from production batches.
/// All form state lives in [controller], owned by the parent page.
class _AddWarehouseDocumentForm extends StatefulWidget {
  const _AddWarehouseDocumentForm({
    required this.controller,
  });

  final WarehouseDocumentFormController controller;

  @override
  State<_AddWarehouseDocumentForm> createState() =>
      _AddWarehouseDocumentFormState();
}

class _AddWarehouseDocumentFormState extends State<_AddWarehouseDocumentForm> {
  final _formKey = GlobalKey<FormState>();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final ctrl = widget.controller;
    final filledItems = ctrl.filledItems;

    if (filledItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta mahsulot qo\'shing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Only manually-added rows without a batch source need color/size validation.
    final manualRows = filledItems.where((r) => r.sourceBatchId == null);

    final hasUnpickedColor =
        manualRows.any((r) => r.selectedColor == null);
    if (hasUnpickedColor) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha qatorlardagi mahsulot rangini tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final hasUnpickedSize = manualRows.any(
      (r) => r.selectedProduct?.productTypeId != null && r.selectedSize == null,
    );
    if (hasUnpickedSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha qatorlardagi mahsulot o\'lchamini tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final previewItems = filledItems.map((row) {
      final productId = row.selectedProduct?.id ?? row.prefilledProductId;
      final productName =
          row.selectedProduct?.name ?? row.prefilledProductName ?? '';
      final quality = row.selectedProduct?.productQuality?.qualityName ??
          row.prefilledQualityName;
      final type =
          row.selectedProduct?.productType?.type ?? row.prefilledTypeName;
      final colorName =
          row.selectedColor?.colorName ?? row.prefilledColorName;
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      final sizeId = row.selectedSize?.id ?? row.prefilledSizeId;
      final sizeLabel =
          row.selectedSize?.dimensions ?? row.prefilledSizeDimensions;
      final sizeLength = row.selectedSize?.length ?? row.prefilledSizeLength;
      final sizeWidth = row.selectedSize?.width ?? row.prefilledSizeWidth;

      return WarehouseItemPreviewRow(
        productId: productId!,
        productName: productName,
        quality: quality,
        type: type,
        color: colorName,
        productColorId: colorId,
        productSizeId: sizeId,
        sizeLabel: sizeLabel,
        sizeLength: sizeLength,
        sizeWidth: sizeWidth,
        quantity: int.tryParse(row.quantityCtrl.text.trim()) ?? 1,
        itemNotes: row.notesCtrl.text.trim().isEmpty
            ? null
            : row.notesCtrl.text.trim(),
        sourceClientShopName: row.sourceClientShopName,
        sourceClientRegion: row.sourceClientRegion,
        isOrderItem: row.sourceType == 'order_item',
        sourceBatchItemId: row.sourceBatchItemId,
      );
    }).toList();

    final args = WarehouseDocumentPreviewArgs(
      type: 'in',
      documentDate: DateTime.now(),
      notes: ctrl.notesCtrl.text.trim().isEmpty
          ? null
          : ctrl.notesCtrl.text.trim(),
      username: ctrl.username.isEmpty ? 'Noma\'lum' : ctrl.username,
      items: previewItems,
    );

    context
        .pushNamed(
      AppRoutes.warehouseDocumentPreviewName,
      extra: args,
    )
        .then((result) {
      if (result != null && mounted) context.pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Kirim hujjati'),
            titleSpacing: 0,
            leading: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                strokeWidth: 2,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text("Ko'rib chiqish"),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Items section label + import button ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                              await ProductionBatchPickerBottomSheet.show(
                            context,
                            existingRows: ctrl.items,
                          );
                          if (result != null && mounted) {
                            ctrl.addRowsFromProductionBatch(
                              result.batch,
                              result.items,
                              quantities: result.quantities,
                            );
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Partiyadan import'),
                      ),
                    ),
                  ],
                ),

                // ── Table header ────────────────────────────────────────────
                const WarehouseDocumentFormTableHeader(),
                const Divider(height: 1, color: AppColors.divider),

                // ── Table rows ──────────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: ctrl.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final row = ctrl.items[index];
                      return WarehouseDocumentFormItemRow(
                        key: ValueKey(row.id),
                        row: row,
                        allItems: ctrl.items,
                        index: index,
                        onRemove: () => ctrl.removeRow(index),
                        onChanged: () {
                          ctrl.promoteIfSentinel(row);
                          ctrl.updateRow(row);
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),

                // ── Notes ───────────────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

                // ── Status bar ──────────────────────────────────────────────
                Builder(builder: (context) {
                  final filled = ctrl.filledItems;
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
                        const Spacer(),
                        Text(
                          'Sana: $_formattedDate  ·  Xodim: ${ctrl.username.isEmpty ? 'Noma\'lum' : ctrl.username}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String get _formattedDate {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Status bar chip
// ══════════════════════════════════════════════════════════════════════════════

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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
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
