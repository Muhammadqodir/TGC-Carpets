import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/domain/entities/order_item_entity.dart';
import '../../domain/usecases/get_orders_for_shipment_usecase.dart';

// ── Result ────────────────────────────────────────────────────────────────────

/// Result returned by [OrderPickerForShipmentSheet.show].
class OrderImportResult {
  final OrderEntity order;

  /// IDs of [OrderItemEntity] the user chose to import.
  final Set<int> selectedItemIds;

  const OrderImportResult({
    required this.order,
    required this.selectedItemIds,
  });
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

/// Two-step bottom sheet for importing items from an order into a shipment:
///   1. Pick an order (status: on_production or done).
///   2. Multi-select unshipped order items with checkboxes.
///
/// Returns [OrderImportResult] or null if dismissed.
class OrderPickerForShipmentSheet extends StatefulWidget {
  const OrderPickerForShipmentSheet({super.key, this.clientId});

  /// When non-null, only orders for this client are shown.
  final int? clientId;

  static Future<OrderImportResult?> show(BuildContext context,
      {int? clientId}) {
    return showModalBottomSheet<OrderImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderPickerForShipmentSheet(clientId: clientId),
    );
  }

  @override
  State<OrderPickerForShipmentSheet> createState() =>
      _OrderPickerForShipmentSheetState();
}

class _OrderPickerForShipmentSheetState
    extends State<OrderPickerForShipmentSheet> {
  // ── Step 1 ────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<OrderEntity> _orders = [];
  bool _isLoadingOrders = true;
  String? _ordersError;

  // ── Step 2 ────────────────────────────────────────────────────────────────
  OrderEntity? _selectedOrder;
  final Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Step 1 helpers ────────────────────────────────────────────────────────

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });

    final result = await sl<GetOrdersForShipmentUseCase>()(
      perPage: 50,
    );

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _ordersError = failure.message;
        _isLoadingOrders = false;
      }),
      (page) {
        final query = _searchCtrl.text.trim().toLowerCase();
        var orders = query.isEmpty
            ? page.data
            : page.data
                .where((o) =>
                    '#${o.id}'.contains(query) ||
                    (o.clientShopName ?? '').toLowerCase().contains(query))
                .toList();

        // Sort: preferred client's orders appear first in the list
        if (widget.clientId != null) {
          orders = [
            ...orders.where((o) => o.clientId == widget.clientId),
            ...orders.where((o) => o.clientId != widget.clientId),
          ];
        }

        setState(() {
          _orders = orders;
          _isLoadingOrders = false;
        });
      },
    );
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetchOrders);
  }

  void _selectOrder(OrderEntity order) {
    final shippableItems = order.items
        .where((i) => (i.shippedQuantity ?? 0) < i.quantity)
        .toList();
    setState(() {
      _selectedOrder = order;
      _selectedItemIds
        ..clear()
        ..addAll(shippableItems.map((i) => i.id));
    });
  }

  void _backToOrders() {
    setState(() {
      _selectedOrder = null;
      _selectedItemIds.clear();
    });
  }

  // ── Step 2 helpers ────────────────────────────────────────────────────────

  void _toggleItem(int id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  void _toggleAll(List<OrderItemEntity> shippable) {
    setState(() {
      if (_selectedItemIds.length == shippable.length) {
        _selectedItemIds.clear();
      } else {
        _selectedItemIds
          ..clear()
          ..addAll(shippable.map((i) => i.id));
      }
    });
  }

  void _confirm() {
    if (_selectedOrder == null || _selectedItemIds.isEmpty) return;
    Navigator.of(context).pop(OrderImportResult(
      order: _selectedOrder!,
      selectedItemIds: Set.unmodifiable(_selectedItemIds),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Title row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
            child: Row(
              children: [
                if (_selectedOrder != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: _backToOrders,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedOrder == null
                            ? 'Buyurtmadan import'
                            : '#${_selectedOrder!.id} — pozitsiyalarni tanlash',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_selectedOrder == null)
                        Text(
                          'Ishlab chiqarishda yoki tayyor buyurtmalar',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        )
                      else if (_selectedOrder!.clientShopName != null)
                        Text(
                          _selectedOrder!.clientShopName!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          if (_selectedOrder == null) ...[
            // ── Step 1: order list ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Buyurtma № yoki mijoz...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Flexible(
              child: _isLoadingOrders
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _ordersError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _ordersError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.error),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _fetchOrders,
                                  child: const Text('Qayta urinish'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _orders.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    HugeIcon(
                                      icon: HugeIcons
                                          .strokeRoundedShoppingCart01,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Yuk chiqarish uchun buyurtma yo\'q',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color:
                                                  AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final order = _orders[i];
                                return InkWell(
                                  onTap: () => _selectOrder(order),
                                  child: _OrderTile(order: order),
                                );
                              },
                            ),
            ),
          ] else ...[
            // ── Step 2: item multi-select ─────────────────────────────────
            _buildItemStep(),
          ],
        ],
      ),
    );
  }

  Widget _buildItemStep() {
    final order = _selectedOrder!;
    final shippable = order.items
        .where((i) => (i.shippedQuantity ?? 0) < i.quantity)
        .toList();
    final fullyShipped = order.items
        .where((i) => (i.shippedQuantity ?? 0) >= i.quantity)
        .toList();
    final allSelected = shippable.isNotEmpty &&
        _selectedItemIds.length == shippable.length;

    return Flexible(
      child: Column(
        children: [
          // Select-all toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
            child: Row(
              children: [
                Text(
                  'Barcha yuborilmaganlar (${shippable.length})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const Spacer(),
                Switch(
                  value: allSelected,
                  onChanged: shippable.isEmpty
                      ? null
                      : (_) => _toggleAll(shippable),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              children: [
                // Shippable items
                ...shippable.map((item) => InkWell(
                      onTap: () => _toggleItem(item.id),
                      child: _OrderItemTile(
                        item: item,
                        isSelected: _selectedItemIds.contains(item.id),
                        isDisabled: false,
                      ),
                    )),
                // Fully-shipped items (greyed out, not selectable)
                if (fullyShipped.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Allaqachon yuborilgan (${fullyShipped.length})',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ...fullyShipped.map((item) => _OrderItemTile(
                        item: item,
                        isSelected: false,
                        isDisabled: true,
                      )),
                ],
              ],
            ),
          ),

          // Confirm button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(
                onPressed: _selectedItemIds.isEmpty ? null : _confirm,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: Text(
                    'Import qilish (${_selectedItemIds.length} ta pozitsiya)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order tile (step 1) ───────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final OrderEntity order;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      'done' => AppColors.success,
      'on_production' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    final unshipped =
        order.items.where((i) => (i.shippedQuantity ?? 0) < i.quantity).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ID badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${order.id}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clientShopName ?? '— Mijoz yo\'q —',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.orderDate.day.toString().padLeft(2, '0')}.${order.orderDate.month.toString().padLeft(2, '0')}.${order.orderDate.year}'
                  '  ·  ${order.items.length} ta  ·  $unshipped ta yuborilmagan',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              order.statusLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// ── Order item tile (step 2) ──────────────────────────────────────────────────

class _OrderItemTile extends StatelessWidget {
  const _OrderItemTile({
    required this.item,
    required this.isSelected,
    required this.isDisabled,
  });

  final OrderItemEntity item;
  final bool isSelected;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final remaining = item.quantity - (item.shippedQuantity ?? 0);
    final textColor =
        isDisabled ? AppColors.textSecondary : null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: isDisabled
                  ? const Icon(Icons.check_circle_outline_rounded,
                      size: 20, color: AppColors.success)
                  : Checkbox(
                      value: isSelected,
                      onChanged: null, // handled by parent InkWell
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (item.colorName != null)
                        _SmallChip(label: item.colorName!),
                      if (item.qualityName != null)
                        _SmallChip(label: item.qualityName!),
                      if (item.productTypeName != null)
                        _SmallChip(label: item.productTypeName!),
                      if (item.sizeLength != null && item.sizeWidth != null)
                        _SmallChip(
                          label: '${item.sizeLength}×${item.sizeWidth}',
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Qty info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isDisabled
                      ? '${item.quantity} / ${item.quantity}'
                      : '$remaining / ${item.quantity}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDisabled
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                ),
                Text(
                  isDisabled ? 'yuborildi' : 'qolgan',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
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

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.25)),
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
