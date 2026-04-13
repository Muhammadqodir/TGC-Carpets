import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../domain/usecases/get_orders_for_shipment_usecase.dart';

/// Bottom sheet that lets the user pick an order (status: on_production or done)
/// to import items into a shipment.
///
/// Returns the selected [OrderEntity] or null if dismissed.
class OrderPickerForShipmentSheet extends StatefulWidget {
  const OrderPickerForShipmentSheet({super.key, this.clientId});

  /// When non-null, only orders for this client are shown.
  final int? clientId;

  static Future<OrderEntity?> show(BuildContext context, {int? clientId}) {
    return showModalBottomSheet<OrderEntity>(
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
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<OrderEntity> _orders = [];
  bool _isLoading = true;
  String? _error;

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

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final useCase = sl<GetOrdersForShipmentUseCase>();
    final result = await useCase(clientId: widget.clientId, perPage: 50);

    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _isLoading = false;
      }),
      (page) {
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? page.data
            : page.data
                .where((o) =>
                    '#${o.id}'.contains(query) ||
                    (o.clientShopName ?? '').toLowerCase().contains(query))
                .toList();
        setState(() {
          _orders = filtered;
          _isLoading = false;
        });
      },
    );
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _fetchOrders);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Handle ─────────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedShoppingCart01,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Buyurtmadan import',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Search ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Buyurtma № yoki mijoz...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.divider),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _fetchOrders,
                                child: const Text('Qayta urinish'),
                              ),
                            ],
                          ),
                        )
                      : _orders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedShoppingCart01,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Yuk chiqarish uchun buyurtma yo\'q',
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
                              controller: scrollController,
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.divider),
                              itemBuilder: (context, index) {
                                final order = _orders[index];
                                return _OrderTile(
                                  order: order,
                                  onTap: () => Navigator.of(context).pop(order),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

// ── Order tile ────────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final OrderEntity order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      'done' => AppColors.success,
      'on_production' => AppColors.warning,
      _ => AppColors.textSecondary,
    };

    final unshippedItems = order.items
        .where((i) => (i.shippedQuantity ?? 0) < i.quantity)
        .length;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          '#${order.id}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      title: Text(
        order.clientShopName ?? '— Mijoz yo\'q —',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        '${order.orderDate.day.toString().padLeft(2, '0')}.${order.orderDate.month.toString().padLeft(2, '0')}.${order.orderDate.year}'
        '  ·  ${order.items.length} mahsulot ($unshippedItems yuborilmagan)',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
      trailing: Container(
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
    );
  }
}
