import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/domain/entities/order_item_entity.dart';
import '../../../orders/domain/usecases/get_orders_usecase.dart';

/// Result returned by [OrderPickerBottomSheet.show].
class OrderImportResult {
  final OrderEntity order;
  final List<OrderItemEntity> items;
  const OrderImportResult({required this.order, required this.items});
}

/// Two-step bottom sheet:
///   1. Pick an order from a searchable list.
///   2. Multi-select items from that order and confirm.
///
/// Returns [OrderImportResult] or null if dismissed.
class OrderPickerBottomSheet extends StatefulWidget {
  const OrderPickerBottomSheet({super.key});

  static Future<OrderImportResult?> show(BuildContext context) {
    return showModalBottomSheet<OrderImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const OrderPickerBottomSheet(),
    );
  }

  @override
  State<OrderPickerBottomSheet> createState() => _OrderPickerBottomSheetState();
}

class _OrderPickerBottomSheetState extends State<OrderPickerBottomSheet> {
  // ── Step 1 state ────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<OrderEntity> _orders = [];
  bool _isLoadingOrders = true;
  String? _ordersError;

  // ── Step 2 state ────────────────────────────────────────────────────────
  OrderEntity? _selectedOrder;
  final Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchOrders(query.trim());
    });
  }

  Future<void> _fetchOrders(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });
    final useCase = sl<GetOrdersUseCase>();
    // Load all orders that have at least one item still available for production
    // (pending, planned, or on_production with uncovered items, incl. from cancelled batches).
    final result = await useCase(forProduction: true, perPage: 100);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _ordersError = failure.toString();
        _isLoadingOrders = false;
      }),
      (page) {
        var data = page.data;
        // Drop orders where every item is already fully covered by active batches.
        data = data
            .where((o) => o.items.any((i) => (i.remainingQuantity ?? i.quantity) > 0))
            .toList();
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          data = data
              .where((o) =>
                  '#${o.id}'.contains(q) ||
                  (o.clientShopName?.toLowerCase().contains(q) ?? false))
              .toList();
        }
        setState(() {
          _orders = data;
          _isLoadingOrders = false;
        });
      },
    );
  }

  void _selectOrder(OrderEntity order) {
    setState(() {
      _selectedOrder = order;
      _selectedItemIds.clear();
      // Pre-select only items that still have quantity pending production.
      for (final item in order.items) {
        final remaining = item.remainingQuantity ?? item.quantity;
        if (remaining > 0) {
          _selectedItemIds.add(item.id);
        }
      }
    });
  }

  void _toggleItem(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _confirm() {
    final order = _selectedOrder;
    if (order == null) return;
    final items =
        order.items.where((i) => _selectedItemIds.contains(i.id)).toList();
    if (items.isEmpty) return;
    Navigator.of(context)
        .pop(OrderImportResult(order: order, items: items));
  }

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

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                if (_selectedOrder != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => setState(() {
                      _selectedOrder = null;
                      _selectedItemIds.clear();
                    }),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (_selectedOrder != null) const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedOrder == null
                            ? 'Buyurtma tanlash'
                            : '#${_selectedOrder!.id} — mahsulotlarni tanlash',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_selectedOrder == null)
                        Text(
                          'Ishlab chiqarishga ega bo\'sh mahsulotli buyurtmalar',
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

          const Divider(height: 1),

          if (_selectedOrder == null) ...[
            // ── Step 1: order list ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: '#ID yoki do\'kon nomi...',
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
                            child: Text(
                              'Buyurtmalar yuklanmadi',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        )
                      : _orders.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Ishlab chiqarishga tayyor buyurtma yo\'q',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppColors.textSecondary),
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
            // ── Step 2: item multi-select ───────────────────────────
            Flexible(
              child: _selectedOrder!.items
                      .every((i) => (i.remainingQuantity ?? i.quantity) <= 0)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Bu buyurtmada mahsulot yo\'q',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // Select all toggle
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                'Barchasi',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                              ),
                              const Spacer(),
                              Switch(
                                value: _selectedOrder!.items
                                    .where((i) =>
                                        (i.remainingQuantity ?? i.quantity) > 0)
                                    .every((i) =>
                                        _selectedItemIds.contains(i.id)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val) {
                                      for (final item
                                          in _selectedOrder!.items) {
                                        if ((item.remainingQuantity ??
                                                item.quantity) >
                                            0) {
                                          _selectedItemIds.add(item.id);
                                        }
                                      }
                                    } else {
                                      _selectedItemIds.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Flexible(
                          child: Builder(builder: (context) {
                            final visibleItems = _selectedOrder!.items
                                .where((i) =>
                                    (i.remainingQuantity ?? i.quantity) > 0)
                                .toList();
                            return ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(0, 4, 0, 0),
                              itemCount: visibleItems.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final item = visibleItems[i];
                                final isSelected =
                                    _selectedItemIds.contains(item.id);
                                return InkWell(
                                  onTap: () => _toggleItem(item.id),
                                  child: _OrderItemTile(
                                    item: item,
                                    isSelected: isSelected,
                                  ),
                                );
                              },
                            );
                          }),
                        ),
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
                  child: Builder(builder: (context) {
                    final pendingCount = (_selectedOrder?.items ?? [])
                        .where((i) =>
                            _selectedItemIds.contains(i.id) &&
                            (i.remainingQuantity ?? i.quantity) > 0)
                        .length;
                    return Text('Import ($pendingCount ta mahsulot)');
                  }),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Order tile ────────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final OrderEntity order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
                  order.clientShopName ?? order.userName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order.items.length} ta mahsulot  ·  ${_fmtDate(order.orderDate)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                    _StatusChip(status: order.status),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ── Order item tile ───────────────────────────────────────────────────────────

class _OrderItemTile extends StatelessWidget {
  final OrderItemEntity item;
  final bool isSelected;
  const _OrderItemTile({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final remaining = item.remainingQuantity ?? item.quantity;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: null, // handled by parent InkWell
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Builder(builder: (context) {
                  final parts = <String>[
                    if (item.colorName != null) item.colorName!,
                    if (item.sizeLength != null && item.sizeWidth != null)
                      '${item.sizeLength}×${item.sizeWidth}',
                  ];
                  if (parts.isEmpty) return const SizedBox.shrink();
                  return Text(
                    parts.join('  ·  '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  );
                }),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$remaining ta',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (item.remainingQuantity != null)
                Text(
                  '/ ${item.quantity} ta',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending'       => ('Kutilmoqda', Colors.orange),
      'planned'       => ('Rejalashtirilgan', Colors.blue),
      'on_production' => ('Ishlab chiqarishda', Colors.purple),
      _               => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
