import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../../core/ui/widgets/count_input.dart';
import '../../../../../core/ui/widgets/desktop_status_bar.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../bloc/shipment_form_bloc.dart';
import '../../bloc/shipment_form_event.dart';
import '../../bloc/shipment_form_state.dart';
import '../../widgets/order_picker_for_shipment_sheet.dart';
import '../../widgets/shipment_form_controller.dart';
import '../../widgets/shipment_item_row.dart';
import '../../../../orders/domain/entities/order_entity.dart';
import '../../../domain/repositories/shipment_repository.dart';
import '../../../../../core/error/failures.dart';

/// Desktop layout for the "add shipment" form.
///
/// Mirrors the AddOrderDesktopPage style:
///   • Top bar: date picker + client picker
///   • Import from order button
///   • Items table: Mahsulot, Rang, Tur, Sifat, O'lcham, Miqdor, Narx, Jami
///   • Notes field
///   • Status bar with totals
class AddShipmentDesktopPage extends StatefulWidget {
  const AddShipmentDesktopPage({super.key, required this.controller});

  final ShipmentFormController controller;

  @override
  State<AddShipmentDesktopPage> createState() => _AddShipmentDesktopPageState();
}

class _AddShipmentDesktopPageState extends State<AddShipmentDesktopPage> {
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
      // Re-fetch prices for loaded rows when client changes
      _refreshLastPrices();
    }
  }

  Future<void> _importFromOrder() async {
    final order = await OrderPickerForShipmentSheet.show(
      context,
      clientId: _selectedClient?.id,
    );
    if (order == null || !mounted) return;

    // Auto-set client from order if not already picked
    if (_selectedClient == null) {
      // We don't have a full ClientEntity from the order, but we can set
      // the display. For submission we use orderId → the backend knows client.
      // Alternatively, show a toast and require the user to pick a client first.
    }

    // Fetch last prices for all variants in this order
    final lastPrices = await _fetchLastPrices(
      order,
      clientId: _selectedClient?.id ?? order.clientId,
    );

    if (!mounted) return;
    widget.controller.importFromOrder(order, lastPrices);
  }

  Future<Map<int, double>> _fetchLastPrices(
    OrderEntity order, {
    int? clientId,
  }) async {
    if (clientId == null) return {};

    final repo = sl<ShipmentRepository>();
    final results = <int, double>{};

    for (final item in order.items) {
      final result = await repo.getLastPrice(
        variantId: item.variantId,
        clientId: clientId,
      );
      result.fold((_) {}, (price) {
        if (price != null) results[item.variantId] = price;
      });
    }
    return results;
  }

  Future<void> _refreshLastPrices() async {
    final ctrl = widget.controller;
    final order = ctrl.importedOrder;
    final clientId = _selectedClient?.id;
    if (order == null || clientId == null) return;

    final prices = await _fetchLastPrices(order, clientId: clientId);
    if (!mounted) return;

    for (final row in ctrl.items) {
      if (prices.containsKey(row.variantId)) {
        row.priceCtrl.text =
            prices[row.variantId]!.toStringAsFixed(2);
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
    final notes = ctrl.notesCtrl.text.trim().isEmpty
        ? null
        : ctrl.notesCtrl.text.trim();

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
                          padding:
                              const EdgeInsets.fromLTRB(24, 12, 24, 8),
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
                        padding:
                            const EdgeInsets.fromLTRB(0, 4, 12, 4),
                        child: TextButton.icon(
                          onPressed: _importFromOrder,
                          icon: const Icon(
                              Icons.download_rounded,
                              size: 16),
                          label:
                              const Text('Buyurtmadan import'),
                        ),
                      ),
                    ],
                  ),

                  // ── Table header ───────────────────────────────────────────
                  const _DesktopTableHeader(),
                  const Divider(height: 1, color: AppColors.divider),

                  // ── Table rows ─────────────────────────────────────────────
                  Expanded(
                    child: ctrl.items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons
                                      .strokeRoundedContainerTruck,
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
                                          color:
                                              AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: ctrl.items.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, color: AppColors.divider),
                            itemBuilder: (context, index) {
                              final row = ctrl.items[index];
                              return _DesktopItemRow(
                                key: ValueKey(row.id),
                                row: row,
                                index: index,
                                onRemove: () => ctrl.removeRow(index),
                                onChanged: ctrl.notifyChanged,
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),

                  // ── Notes ──────────────────────────────────────────────────
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

                  // ── Status bar ─────────────────────────────────────────────
                  DesktopStatusBar(
                    child: Row(
                      children: [
                        _TotalChip(
                          label: 'Mahsulotlar',
                          value: '${ctrl.filledItems.length}',
                        ),
                        const SizedBox(width: 16),
                        _TotalChip(
                          label: 'Jami dona',
                          value: '${ctrl.totalQuantity}',
                        ),
                        const SizedBox(width: 16),
                        _TotalChip(
                          label: 'Jami m²',
                          value:
                              '${ctrl.totalSqm.toStringAsFixed(2)} m²',
                        ),
                        const SizedBox(width: 16),
                        _TotalChip(
                          label: 'Jami summa',
                          value:
                              '\$${ctrl.grandTotal.toStringAsFixed(2)}',
                        ),
                        const Spacer(),
                        Text(
                          'Sana: $_formattedDate',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.textSecondary),
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
    );
  }
}

// ── Table header ──────────────────────────────────────────────────────────────

class _DesktopTableHeader extends StatelessWidget {
  const _DesktopTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: const Row(
        children: [
          _HeaderCell(label: '#', fixedWidth: 40),
          _HeaderCell(label: 'Mahsulot', flex: 3),
          _HeaderCell(label: 'Rang', flex: 2),
          _HeaderCell(label: 'Tur', flex: 1),
          _HeaderCell(label: 'Sifat', flex: 1),
          _HeaderCell(label: "O'lcham", flex: 2),
          _HeaderCell(label: 'Miqdor', fixedWidth: 110),
          _HeaderCell(label: 'Narx', fixedWidth: 110),
          _HeaderCell(label: 'Jami', fixedWidth: 100),
          SizedBox(width: 40),
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

// ── Item row ──────────────────────────────────────────────────────────────────

class _DesktopItemRow extends StatelessWidget {
  const _DesktopItemRow({
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
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
            flex: 3,
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
                            style:
                                Theme.of(context).textTheme.bodyMedium,
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
                          ?.copyWith(
                              color: AppColors.textSecondary),
                    ),
            ),
          ),

          // Tur
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                row.typeName ?? '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: row.typeName == null
                          ? AppColors.textSecondary
                          : null,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Sifat
          Expanded(
            flex: 1,
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
          Expanded(
            flex: 2,
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
            width: 110,
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
              child: TextFormField(
                controller: row.priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  hintText: '0.00',
                  prefixText: '\$',
                ),
                validator: (v) {
                  final val = double.tryParse(
                      v?.trim().replaceAll(',', '.') ?? '');
                  if (val == null || val <= 0) {
                    return 'Narx kiriting';
                  }
                  return null;
                },
                onChanged: (_) => onChanged(),
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
