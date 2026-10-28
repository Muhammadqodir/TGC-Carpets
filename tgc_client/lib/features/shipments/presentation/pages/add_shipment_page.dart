import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../core/ui/widgets/count_input.dart';
import '../../../../core/ui/widgets/desktop_status_bar.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../data/services/shipment_form_draft_service.dart';
import '../bloc/shipment_form_bloc.dart';
import '../bloc/shipment_form_event.dart';
import '../bloc/shipment_form_state.dart';
import '../widgets/stock_picker_for_shipment_sheet.dart'
    show StockPickerForShipmentSheet;
import '../widgets/shipment_form_controller.dart';
import '../widgets/shipment_item_row.dart';
import '../widgets/shipment_qr_scanner_page.dart';

/// Entry point for the "add shipment" form.
///
/// Owns the [ShipmentFormController] so state survives layout switches.
/// Provides the [ShipmentFormBloc] to the subtree.
///
/// Auto-saves a draft on every change so closing the page mid-load does not
/// throw away a half-scanned lorry. The draft is dropped only once the
/// shipment is saved, or when the user clears the form on purpose.
class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  late final ShipmentFormController _ctrl;
  final _formKey = GlobalKey<FormState>();

  ClientEntity? _selectedClient;
  late DateTime _shipmentDate;

  /// True once the user has picked a date themselves. An untouched date is
  /// left out of the draft so a draft written yesterday does not silently
  /// back-date the shipment.
  bool _datePicked = false;

  ShipmentFormDraftService? _draft;

  /// Set while restoring or clearing, so those writes do not save over the
  /// draft they are in the middle of reading or deleting.
  bool _suspendSave = false;
  bool _ready = false;

  bool get _hasClient => _selectedClient != null;

  @override
  void initState() {
    super.initState();
    _ctrl = ShipmentFormController();
    _shipmentDate = DateTime.now();
    _ctrl.addListener(_onFormChanged);
    _initDraft();
  }

  Future<void> _initDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _draft = ShipmentFormDraftService(prefs);

    _suspendSave = true;
    final draft = await _draft!.restore();

    if (!mounted) {
      // Page closed while the draft was loading. Its rows own text
      // controllers the form never took ownership of.
      for (final row in draft?.rows ?? const <ShipmentItemRow>[]) {
        row.dispose();
      }
      return;
    }

    if (draft != null) {
      _ctrl.restoreFrom(newItems: draft.rows, notes: draft.notes);
      _selectedClient = draft.client;
      if (draft.shipmentDate != null) {
        _shipmentDate = draft.shipmentDate!;
        _datePicked = true;
      }
    }
    _suspendSave = false;

    setState(() => _ready = true);
  }

  void _onFormChanged() {
    if (!_ready || _suspendSave) return;
    _draft?.save(
      _ctrl,
      client: _selectedClient,
      shipmentDate: _datePicked ? _shipmentDate : null,
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onFormChanged);
    _ctrl.dispose();
    super.dispose();
  }

  String get _formattedDate =>
      '${_shipmentDate.day.toString().padLeft(2, '0')}.${_shipmentDate.month.toString().padLeft(2, '0')}.${_shipmentDate.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _shipmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() {
        _shipmentDate = picked;
        _datePicked = true;
      });
      _onFormChanged();
    }
  }

  Future<void> _pickClient() async {
    final client = await ClientPickerBottomSheet.show(context);
    if (client != null && mounted) {
      setState(() => _selectedClient = client);
      _onFormChanged();
    }
  }

  /// One last look before saving a form whose rows go past the client's
  /// order, or take carpets made for someone else. The rows already say so
  /// one by one (_RowConflictNote); this adds them up, because saving is what
  /// opens the extra order lines and moves the other clients' production.
  /// Nothing to confirm → true straight away.
  Future<bool> _confirmConflicts(List<ShipmentItemRow> rows) async {
    final offOrder = rows
        .where((r) => r.isOffOrder)
        .fold<int>(0, (sum, r) => sum + r.parsedQuantity);
    final beyond = rows.fold<int>(0, (sum, r) => sum + r.beyondOrder);
    final others = {for (final r in rows) ...r.producedForClients};

    if (offOrder == 0 && beyond == 0 && others.isEmpty) return true;

    final lines = [
      if (beyond > 0) '• $beyond dona buyurtmadan ortiqcha yuklanmoqda.',
      if (offOrder > 0) '• $offOrder dona mijoz buyurtmasida yo\'q.',
      if (beyond > 0 || offOrder > 0)
        'Ular uchun "${_selectedClient?.shopName ?? ''}" mijoziga alohida '
            'buyurtma qatori ochiladi.',
      if (others.isNotEmpty)
        '• ${others.join(', ')} uchun ishlab chiqarilgan gilamlar bor — '
            'ularning tayyor soni kamayadi va buyurtmasi qayta ishlab '
            'chiqarishga qaytadi.',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buyurtmaga mos kelmaydigan mahsulotlar'),
        content: Text(lines.join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tekshirish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  /// Empties the form and throws away the stored draft.
  Future<void> _clearForm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Formani tozalash'),
        content: const Text(
            'Barcha kiritilgan ma\'lumotlar o\'chib ketadi. Davom etasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _suspendSave = true;
    _ctrl.clearForm();
    setState(() {
      _selectedClient = null;
      _shipmentDate = DateTime.now();
      _datePicked = false;
    });
    await _draft?.clear();
    _suspendSave = false;
  }

  Future<void> _importFromOrder() async {
    final result = await StockPickerForShipmentSheet.show(context);
    if (result == null || !mounted) return;

    if (_selectedClient == null) {
      setState(() {
        _selectedClient = ClientEntity(
          id: result.client.id,
          uuid: '',
          shopName: result.client.shopName,
          region: result.client.region,
          phone: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
    }

    // No last-price fetch here any more: this form does not carry prices, so
    // the round trip per item bought nothing. The same lookup now backs the
    // "Oxirgi narxlar" button in the pricing feature, where prices are typed.
    _ctrl.importFromStock(result.selectedItems);
  }

  Future<void> _scanQr() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval mijozni tanlang.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ShipmentQrScannerPage(
        clientId: _selectedClient!.id,
        clientName: _selectedClient!.shopName,
        controller: _ctrl,
      ),
    ));
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasClient) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mijozni tanlash shart.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final filled = _ctrl.filledItems;

    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta mahsulot bo\'lishi shart.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!await _confirmConflicts(filled)) return;
    if (!context.mounted) return;

    final dateStr = _shipmentDate.toIso8601String();
    final notes = _ctrl.notesCtrl.text.trim().isEmpty
        ? null
        : _ctrl.notesCtrl.text.trim();

    final items = filled
        .map((r) => {
              // Null for a scanned carpet with no order line; the backend
              // creates one, but only because `scanned` vouches that a real
              // labelled carpet is being shipped.
              'order_item_id': r.orderItemId,
              'product_variant_id': r.variantId,
              'quantity': r.parsedQuantity,
              // No price: the backend stores 0.00 and the pricing feature
              // fills it in afterwards.
              if (r.scanned) 'scanned': true,
              // Lets the backend move each scanned carpet's production record
              // onto the line it is shipping against, so a carpet made for
              // another client stops counting as ready for them.
              if (r.scanned && r.scannedBatchItemIds.isNotEmpty)
                'scanned_batch_item_ids': r.scannedBatchItemIds,
            })
        .toList();

    context.read<ShipmentFormBloc>().add(ShipmentFormSubmitted(
          clientId: _selectedClient!.id,
          orderId: _ctrl.importedOrder?.id,
          shipmentDatetime: dateStr,
          notes: notes,
          items: items,
        ));
  }

  @override
  Widget build(BuildContext context) {
    // Holds the page back a frame or two until the draft is read, so the
    // restored rows do not pop in after the user has started typing.
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return BlocProvider(
      create: (_) => sl<ShipmentFormBloc>(),
      child: BlocListener<ShipmentFormBloc, ShipmentFormState>(
        listener: (context, state) {
          if (state is ShipmentFormSuccess) {
            _draft?.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Yuk chiqarish saqlandi.'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop(true);
          } else if (state is ShipmentFormFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Yangi yuk chiqarish'),
                titleSpacing: 0,
                leading: IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    strokeWidth: 2,
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Formani tozalash',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedClean,
                      size: 18,
                      strokeWidth: 2,
                    ),
                    onPressed: _clearForm,
                  ),
                  BlocBuilder<ShipmentFormBloc, ShipmentFormState>(
                    builder: (context, state) {
                      if (state is ShipmentFormSubmitting) {
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
                      return FilledButton.icon(
                        onPressed: () => _submit(context),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Saqlash'),
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
                    // ── Date + Client bar ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                            bottom: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(
                        children: [
                          // Date picker
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 40,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.divider),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formattedDate,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Client picker
                          Expanded(
                            child: InkWell(
                              onTap: _pickClient,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: !_hasClient
                                        ? AppColors.divider
                                        : AppColors.primary,
                                    width: !_hasClient ? 1.0 : 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: _hasClient
                                      ? AppColors.primary
                                          .withValues(alpha: 0.05)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.store_outlined,
                                      size: 16,
                                      color: !_hasClient
                                          ? AppColors.textSecondary
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedClient?.shopName ??
                                            'Mijoz tanlash...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: !_hasClient
                                                  ? AppColors.textSecondary
                                                  : null,
                                            ),
                                      ),
                                    ),
                                    if (_selectedClient != null)
                                      GestureDetector(
                                        onTap: () {
                                          setState(
                                              () => _selectedClient = null);
                                          _onFormChanged();
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Items header + import buttons ──────────────────────────
                    // Two labelled buttons ate a phone's whole row and left
                    // the heading clipped mid-word, so below the desktop
                    // breakpoint they collapse to icons and keep their labels
                    // as tooltips.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >=
                            AppConstants.desktopBreakpoint;

                        return Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 8, 8),
                                child: Text(
                                  'Mahsulotlar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                            if (isDesktop) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                                child: TextButton.icon(
                                  onPressed: _scanQr,
                                  icon: const Icon(
                                      Icons.qr_code_scanner_rounded, size: 16),
                                  label: const Text('QR skanerlash'),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                                child: TextButton.icon(
                                  onPressed: _importFromOrder,
                                  icon: const Icon(Icons.download_rounded,
                                      size: 16),
                                  label: const Text('Buyurtmadan import'),
                                ),
                              ),
                            ] else ...[
                              IconButton(
                                onPressed: _scanQr,
                                icon: const Icon(
                                    Icons.qr_code_scanner_rounded, size: 22),
                                color: AppColors.primary,
                                tooltip: 'QR skanerlash',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: _importFromOrder,
                                icon: const Icon(Icons.download_rounded,
                                    size: 22),
                                color: AppColors.primary,
                                tooltip: 'Buyurtmadan import',
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 4),
                            ],
                          ],
                        );
                      },
                    ),

                    // ── Table header ───────────────────────────────────────────
                    const _TableHeader(),
                    const Divider(height: 1, color: AppColors.divider),

                    // ── Table rows ─────────────────────────────────────────────
                    Expanded(
                      child: _ctrl.items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedContainerTruck,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Buyurtmadan import qiling',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: _ctrl.items.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.divider),
                              itemBuilder: (context, index) {
                                final row = _ctrl.items[index];
                                return LayoutBuilder(
                                    builder: (context, constraints) {
                                  final isDesktop = constraints.maxWidth >=
                                      AppConstants.desktopBreakpoint;
                                  if (isDesktop) {
                                    return _ItemRow(
                                      key: ValueKey(row.id),
                                      row: row,
                                      index: index,
                                      onRemove: () => _ctrl.removeRow(index),
                                      onChanged: _ctrl.notifyChanged,
                                    );
                                  } else {
                                    return _ItemRowMobile(
                                      key: ValueKey(row.id),
                                      row: row,
                                      index: index,
                                      onRemove: () => _ctrl.removeRow(index),
                                      onChanged: _ctrl.notifyChanged,
                                    );
                                  }
                                });
                              },
                            ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),

                    // ── Notes ──────────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: TextFormField(
                        controller: _ctrl.notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Izoh (ixtiyoriy)',
                          hintText: "Qo'shimcha ma'lumot...",
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),

                    // ── Status bar ─────────────────────────────────────────────
                    DesktopStatusBar(
                      child: Row(
                        children: [
                          _TotalChip(
                            label: 'Mahsulotlar',
                            value: '${_ctrl.filledItems.length}',
                          ),
                          const SizedBox(width: 16),
                          _TotalChip(
                            label: 'Jami dona',
                            value: '${_ctrl.totalQuantity}',
                          ),
                          const SizedBox(width: 16),
                          _TotalChip(
                            label: 'Jami m²',
                            value: '${_ctrl.totalSqm.toStringAsFixed(2)} m²',
                          ),
                          const Spacer(),
                          Text(
                            'Sana: $_formattedDate',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppConstants.desktopBreakpoint;
        return Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (isDesktop) ...[
                _HeaderCell(label: '#', fixedWidth: 40),
              ],
              _HeaderCell(label: 'Mahsulot', flex: 2),
              if (isDesktop) ...[
                _HeaderCell(label: 'Rang', flex: 2),
                _HeaderCell(label: 'Tur', flex: 2),
                _HeaderCell(label: 'Sifat', flex: 2),
                _HeaderCell(label: "O'lcham", fixedWidth: 110),
                _HeaderCell(label: 'Miqdor', fixedWidth: 150),
              ],
              if (!isDesktop) ...[
                _HeaderCell(label: 'Miqdor', fixedWidth: 130),
              ],
              SizedBox(width: 40),
            ],
          ),
        );
      },
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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

// ── Item row ──────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  final ShipmentItemRow row;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isEven = index.isEven;

    return Container(
      color: isEven ? null : AppColors.surface.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // #
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),

          // Mahsulot
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    row.edgeCode != null
                        ? '${row.productName} [${row.edgeCode}]'
                        : row.productName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _RowConflictNote(row: row),
                ],
              ),
            ),
          ),

          // Rang
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: row.colorName != null
                  ? Row(
                      children: [
                        AppThumbnail(
                          imageUrl: row.colorImageUrl,
                          size: 24,
                          borderRadius: 4,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row.colorName!,
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

          // Tur
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                row.typeName ?? '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          row.typeName == null ? AppColors.textSecondary : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Sifat
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                row.qualityName ?? '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: row.qualityName == null
                          ? AppColors.textSecondary
                          : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // O'lcham
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                row.sizeLabel ?? '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: row.sizeLabel == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: row.sizeLabel != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
              ),
            ),
          ),

          // Miqdor
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CountInput(
                controller: row.quantityCtrl,
                min: 1,
                // No max: loading more than the order owes is allowed, and
                // _RowConflictNote says what happens to the excess. A cap
                // here used to stop "+" silently — and at 0 on off-order rows.
                onChanged: () => onChanged(),
              ),
            ),
          ),

          // Remove
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRowMobile extends StatelessWidget {
  const _ItemRowMobile({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  final ShipmentItemRow row;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isEven = index.isEven;

    return Container(
      color: isEven ? null : AppColors.surface.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mahsulot
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppThumbnail(
                        imageUrl: row.colorImageUrl,
                        size: 24,
                        borderRadius: 4,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BodyText(
                              text:
                                  "${row.edgeCode != null ? '${row.productName} [${row.edgeCode}]' : row.productName}/${row.colorName?.toUpperCase() ?? ''}",
                            ),
                            Text(
                              row.sizeLabel ?? '—',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: row.sizeLabel == null
                                        ? AppColors.textSecondary
                                        : AppColors.primary,
                                    fontWeight: row.sizeLabel != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppBadge(
                        label: row.qualityName ?? '—',
                        color: AppColors.primary,
                      ),
                      AppBadge(
                        label: row.typeName ?? '—',
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  _RowConflictNote(row: row),
                ],
              ),
            ),
          ),

          // Miqdor
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CountInput(
                controller: row.quantityCtrl,
                height: 35,
                min: 1,
                // No max: loading more than the order owes is allowed, and
                // _RowConflictNote says what happens to the excess. A cap
                // here used to stop "+" silently — and at 0 on off-order rows.
                onChanged: () => onChanged(),
              ),
            ),
          ),

          // Remove
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.remove_circle_outline_rounded,
                size: 20,
                color: AppColors.error,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

/// What is unusual about a row, in one line under its name: a carpet this
/// client never ordered, carpets beyond what the order line owes, or the
/// other client a scanned carpet was produced for. None of it blocks saving;
/// it tells the worker what saving will do, before they confirm it.
class _RowConflictNote extends StatelessWidget {
  const _RowConflictNote({required this.row});

  final ShipmentItemRow row;

  @override
  Widget build(BuildContext context) {
    final notes = <(IconData, Color, String)>[
      if (row.isOffOrder)
        (
          Icons.add_box_outlined,
          AppColors.warning,
          'Buyurtmada yo\'q — saqlanganda yangi buyurtma qatori ochiladi',
        ),
      if (row.beyondOrder > 0)
        (
          Icons.warning_amber_rounded,
          AppColors.warning,
          'Buyurtmadan ${row.beyondOrder} dona ortiq '
              '(buyurtmada ${row.parsedQuantity - row.beyondOrder} dona qolgan) — '
              'ortiqchasi alohida buyurtma qatoriga yoziladi',
        ),
      if (row.producedForClients.isNotEmpty)
        (
          Icons.swap_horiz_rounded,
          AppColors.error,
          '${row.producedForClients.join(', ')} uchun ishlab chiqarilgan — '
              'ularning tayyor soni kamayadi',
        ),
    ];

    if (notes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, color, text) in notes)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

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
