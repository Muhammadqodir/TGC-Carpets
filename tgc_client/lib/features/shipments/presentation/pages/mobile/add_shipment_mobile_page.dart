import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../../domain/repositories/shipment_repository.dart';
import '../../bloc/shipment_form_bloc.dart';
import '../../bloc/shipment_form_event.dart';
import '../../bloc/shipment_form_state.dart';
import '../../widgets/order_picker_for_shipment_sheet.dart'
    show OrderImportResult, OrderPickerForShipmentSheet;
import '../../widgets/shipment_form_controller.dart';
import '../../widgets/shipment_item_row.dart';

/// Mobile layout for the "add shipment" form.
/// All form state lives in [controller], owned by the parent [AddShipmentPage].
class AddShipmentMobilePage extends StatefulWidget {
  const AddShipmentMobilePage({super.key, required this.controller});

  final ShipmentFormController controller;

  @override
  State<AddShipmentMobilePage> createState() => _AddShipmentMobilePageState();
}

class _AddShipmentMobilePageState extends State<AddShipmentMobilePage> {
  final _formKey = GlobalKey<FormState>();

  ClientEntity? _selectedClient;
  late DateTime _shipmentDate;

  bool get _hasClient => _selectedClient != null;

  @override
  void initState() {
    super.initState();
    _shipmentDate = DateTime.now();
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
      _refreshLastPrices();
    }
  }

  Future<void> _importFromOrder() async {
    final result = await OrderPickerForShipmentSheet.show(
      context,
      clientId: _selectedClient?.id,
    );
    if (result == null || !mounted) return;

    final lastPrices = await _fetchLastPrices(
      result,
      clientId: _selectedClient?.id ?? result.order.clientId,
    );
    if (!mounted) return;
    widget.controller.importFromOrder(
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
    final ctrl = widget.controller;
    final clientId = _selectedClient?.id;
    if (ctrl.items.isEmpty || clientId == null) return;
    final repo = sl<ShipmentRepository>();
    final prices = <int, double>{};
    for (final row in ctrl.items) {
      final r = await repo.getLastPrice(
          variantId: row.variantId, clientId: clientId);
      r.fold((_) {}, (price) {
        if (price != null) prices[row.variantId] = price;
      });
    }
    if (!mounted) return;
    for (final row in ctrl.items) {
      if (prices.containsKey(row.variantId)) {
        row.priceCtrl.text = prices[row.variantId]!.toStringAsFixed(2);
      }
    }
    ctrl.notifyChanged();
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

    final ctrl = widget.controller;
    final filled = ctrl.filledItems;

    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Buyurtmadan kamida bitta mahsulot import qiling."),
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
    final notes =
        ctrl.notesCtrl.text.trim().isEmpty ? null : ctrl.notesCtrl.text.trim();

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
          orderId: ctrl.importedOrder?.id,
          shipmentDatetime: dateStr,
          notes: notes,
          items: items,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ShipmentFormBloc, ShipmentFormState>(
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
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          return Scaffold(
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
            ),
            body: Stack(
              children: [
                SafeArea(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ── Date ──────────────────────────────────────────
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
                                  _formattedDate,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Client ────────────────────────────────────────
                        InkWell(
                          onTap: _pickClient,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _hasClient
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: _hasClient ? 1.5 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: _hasClient
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : AppColors.surface,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.store_outlined,
                                  size: 18,
                                  color: _hasClient
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 10),
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
                        const SizedBox(height: 20),

                        // ── Section header + import button ────────────────
                        Row(
                          children: [
                            Text(
                              'Mahsulotlar',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _importFromOrder,
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Buyurtmadan import'),
                              style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ── Item cards ────────────────────────────────────
                        if (ctrl.items.isEmpty)
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 32),
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
                            ),
                          )
                        else
                          ...ctrl.items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            return _MobileShipmentItemCard(
                              key: ValueKey(row.id),
                              row: row,
                              index: index,
                              onRemove: () => ctrl.removeRow(index),
                              onChanged: ctrl.notifyChanged,
                            );
                          }),

                        const SizedBox(height: 16),

                        // ── Notes ─────────────────────────────────────────
                        TextFormField(
                          controller: ctrl.notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Izoh (ixtiyoriy)',
                            hintText: "Qo'shimcha ma'lumot...",
                            alignLabelWithHint: true,
                          ),
                        ),

                        // ── Totals summary ────────────────────────────────
                        if (ctrl.filledItems.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _MobileTotalsCard(ctrl: ctrl),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // ── Submit button ──────────────────────────────────────────
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: SafeArea(
                    top: false,
                    child: BlocBuilder<ShipmentFormBloc, ShipmentFormState>(
                      builder: (context, state) {
                        if (state is ShipmentFormSubmitting) {
                          return FilledButton(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50)),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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

// ── Mobile item card ──────────────────────────────────────────────────────────

class _MobileShipmentItemCard extends StatelessWidget {
  const _MobileShipmentItemCard({
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  '${index + 1}-mahsulot',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
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

            // ── Product + color ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppThumbnail(
                  imageUrl: row.colorImageUrl,
                  size: 40,
                  borderRadius: 6,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.productName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (row.colorName != null)
                        Text(
                          row.colorName!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Specs chips ───────────────────────────────────────────────
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (row.qualityName != null)
                  _SpecChip(label: row.qualityName!),
                if (row.typeName != null) _SpecChip(label: row.typeName!),
                if (row.sizeLabel != null)
                  _SpecChip(
                    label: row.sizeLabel!,
                    color: AppColors.primary,
                  ),
                _SpecChip(
                  label: 'Max: ${row.availableQuantity}',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),

            // ── Qty + Price row ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Miqdor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Miqdor',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      CountInput(
                        controller: row.quantityCtrl,
                        min: 1,
                        max: row.availableQuantity,
                        onChanged: onChanged,
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Narx (price per m²)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Narx (m² uchun)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: row.priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          hintText: '0.00',
                          prefixText: '\$',
                        ),
                        validator: (v) {
                          final val = double.tryParse(
                              v?.trim().replaceAll(',', '.') ?? '');
                          if (val == null || val <= 0) return 'Narx kiriting';
                          return null;
                        },
                        onChanged: (_) => onChanged(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Line total ────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: ListenableBuilder(
                listenable: Listenable.merge(
                    [row.quantityCtrl, row.priceCtrl]),
                builder: (context, _) => Text(
                  'Jami: \$${row.lineTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spec chip ─────────────────────────────────────────────────────────────────

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Totals card ───────────────────────────────────────────────────────────────

class _MobileTotalsCard extends StatelessWidget {
  const _MobileTotalsCard({required this.ctrl});

  final ShipmentFormController ctrl;

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
        children: [
          _TotalRow(
            label: 'Mahsulotlar',
            value: '${ctrl.filledItems.length} xil',
          ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Jami dona',
            value: '${ctrl.totalQuantity}',
          ),
          const SizedBox(height: 4),
          _TotalRow(
            label: 'Jami m²',
            value: '${ctrl.totalSqm.toStringAsFixed(2)} m²',
          ),
          const Divider(height: 16, color: AppColors.divider),
          _TotalRow(
            label: 'Jami summa',
            value: '\$${ctrl.grandTotal.toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: bold ? AppColors.primary : null,
              ),
        ),
      ],
    );
  }
}
