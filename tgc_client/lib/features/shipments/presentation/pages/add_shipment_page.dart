import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/price_input.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../core/ui/widgets/count_input.dart';
import '../../../../core/ui/widgets/desktop_status_bar.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../bloc/shipment_form_bloc.dart';
import '../bloc/shipment_form_event.dart';
import '../bloc/shipment_form_state.dart';
import '../widgets/order_picker_for_shipment_sheet.dart'
    show OrderImportResult, OrderPickerForShipmentSheet;
import '../widgets/shipment_form_controller.dart';
import '../widgets/shipment_item_row.dart';
import '../../domain/repositories/shipment_repository.dart';

/// Entry point for the "add shipment" form.
///
/// Owns the [ShipmentFormController] so state survives layout switches.
/// Provides the [ShipmentFormBloc] to the subtree.
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

  bool get _hasClient => _selectedClient != null;

  @override
  void initState() {
    super.initState();
    _ctrl = ShipmentFormController();
    _shipmentDate = DateTime.now();
  }

  @override
  void dispose() {
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
    if (picked != null && mounted) setState(() => _shipmentDate = picked);
  }

  Future<void> _pickClient() async {
    final client = await ClientPickerBottomSheet.show(context);
    if (client != null && mounted) {
      setState(() => _selectedClient = client);
      // Re-fetch prices for loaded rows when client changes
      _refreshLastPrices();
    }
  }

  Future<void> _importFromOrder() async {
    final result = await OrderPickerForShipmentSheet.show(
      context,
      clientId: _selectedClient?.id,
    );
    if (result == null || !mounted) return;

    // Autofill client from the imported order when none is selected yet
    if (_selectedClient == null && result.order.clientId != null) {
      setState(() {
        _selectedClient = ClientEntity(
          id: result.order.clientId!,
          uuid: '',
          shopName: result.order.clientShopName ?? 'Noma\'lum',
          region: result.order.clientRegion ?? '',
          phone: result.order.clientPhone,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      });
    }

    final lastPrices = await _fetchLastPrices(
      result,
      clientId: _selectedClient?.id ?? result.order.clientId,
    );

    if (!mounted) return;
    _ctrl.importFromOrder(
      result.order,
      lastPrices,
      selectedItemIds: result.selectedItemIds,
    );
  }

  Future<Map<int, double>> _fetchLastPrices(
    OrderImportResult result, {
    int? clientId,
  }) async {
    if (clientId == null) return {};

    final repo = sl<ShipmentRepository>();
    final itemsToFetch = result.order.items
        .where((i) => result.selectedItemIds.contains(i.id))
        .toList();
    final prices = <int, double>{};

    for (final item in itemsToFetch) {
      final r = await repo.getLastPrice(
        variantId: item.variantId,
        clientId: clientId,
      );
      r.fold((_) {}, (price) {
        if (price != null) prices[item.variantId] = price;
      });
    }
    return prices;
  }

  Future<void> _refreshLastPrices() async {
    final order = _ctrl.importedOrder;
    final clientId = _selectedClient?.id;
    if (order == null || clientId == null) return;

    final repo = sl<ShipmentRepository>();
    final prices = <int, double>{};
    for (final row in _ctrl.items) {
      final r =
          await repo.getLastPrice(variantId: row.variantId, clientId: clientId);
      r.fold((_) {}, (price) {
        if (price != null) prices[row.variantId] = price;
      });
    }
    if (!mounted) return;

    for (final row in _ctrl.items) {
      if (prices.containsKey(row.variantId)) {
        row.priceCtrl.text = prices[row.variantId]!.toStringAsFixed(2);
      }
    }
    _ctrl.notifyChanged();
  }

  void _submit() {
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

    final hasZeroPrice = filled.any((r) => r.parsedPrice <= 0);
    if (hasZeroPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcha mahsulotlar uchun narx kiriting.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final dateStr = _shipmentDate.toIso8601String();
    final notes = _ctrl.notesCtrl.text.trim().isEmpty
        ? null
        : _ctrl.notesCtrl.text.trim();

    final items = filled
        .map((r) => {
              'order_item_id': r.orderItemId,
              'product_variant_id': r.variantId,
              'quantity': r.parsedQuantity,
              'price': r.parsedPrice,
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
    return BlocProvider(
      create: (_) => sl<ShipmentFormBloc>(),
      child: BlocListener<ShipmentFormBloc, ShipmentFormState>(
        listener: (context, state) {
          if (state is ShipmentFormSuccess) {
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
                        onPressed: _submit,
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
                                        onTap: () => setState(
                                            () => _selectedClient = null),
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

                    // ── Items header + import button ───────────────────────────
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
                            onPressed: _importFromOrder,
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Buyurtmadan import'),
                          ),
                        ),
                      ],
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
                          const SizedBox(width: 16),
                          _TotalChip(
                            label: 'Jami summa',
                            value: '\$${_ctrl.grandTotal.toStringAsFixed(2)}',
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
                _HeaderCell(label: 'Narx', fixedWidth: 110),
                _HeaderCell(label: 'Narx(umumiy)', fixedWidth: 100)
              ],
              if (!isDesktop) ...[
                _HeaderCell(label: 'Miqdor/Narx', fixedWidth: 130),
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
              child: Text(
                row.productName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                max: row.availableQuantity,
                onChanged: () => onChanged(),
              ),
            ),
          ),

          // Narx
          SizedBox(
            width: 110,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PriceInput(
                priceCtrl: row.priceCtrl,
                onChanged: onChanged,
              ),
            ),
          ),

          // Jami (read-only total)
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '\$${row.lineTotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
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
                                  "${row.productName}/${row.colorName?.toUpperCase() ?? ''}",
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
                  )
                ],
              ),
            ),
          ),

          // Narx / Miqdor
          SizedBox(
            width: 130,
            child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    CountInput(
                      controller: row.quantityCtrl,
                      height: 35,
                      min: 1,
                      max: row.availableQuantity,
                      onChanged: () => onChanged(),
                    ),
                    SizedBox(height: 4),
                    PriceInput(
                      priceCtrl: row.priceCtrl,
                      onChanged: onChanged,
                      height: 35,
                    ),
                  ],
                )),
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
