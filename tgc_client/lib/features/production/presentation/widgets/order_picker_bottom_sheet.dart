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
  const OrderPickerBottomSheet({super.key, this.clientId});

  /// When set, only orders belonging to this client are shown.
  final int? clientId;

  static Future<OrderImportResult?> show(BuildContext context, {int? clientId}) {
    return showModalBottomSheet<OrderImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderPickerBottomSheet(clientId: clientId),
    );
  }

  @override
  State<OrderPickerBottomSheet> createState() => _OrderPickerBottomSheetState();
}

class _QualityGroup {
  final String? qualityName;
  final String label;
  final List<OrderItemEntity> items;

  _QualityGroup({
    required this.qualityName,
    required this.label,
    required this.items,
  });
}

class _OrderPickerBottomSheetState extends State<OrderPickerBottomSheet> {
  // ── Step 1 ─────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<OrderEntity> _orders = [];
  bool _isLoadingOrders = true;
  String? _ordersError;

  // ── Step 2 ─────────────────────────────────────────────────────────────────
  OrderEntity? _selectedOrder;
  List<_QualityGroup> _qualityGroups = [];
  _QualityGroup? _activeQuality;
  final Set<int> _selectedItemIds = {};

  bool get _onOrdersStep => _selectedOrder == null;
  bool get _onQualitiesStep => _selectedOrder != null && _activeQuality == null;
  bool get _onItemsStep => _activeQuality != null;

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

  // ── Search ─────────────────────────────────────────────────────────────────

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
    final result = await sl<GetOrdersUseCase>()(
      forProduction: true,
      perPage: 100,
      clientId: widget.clientId,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _ordersError = failure.toString();
        _isLoadingOrders = false;
      }),
      (page) {
        var data = page.data;
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

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _selectOrder(OrderEntity order) {
    final visible = order.items
        .where((i) => (i.remainingQuantity ?? i.quantity) > 0)
        .toList();
    setState(() {
      _selectedOrder = order;
      _qualityGroups = _buildQualityGroups(visible);
      _activeQuality = null;
      _selectedItemIds.clear();
    });
  }

  void _selectQuality(_QualityGroup quality) {
    setState(() {
      _activeQuality = quality;
    });
  }

  void _back() {
    setState(() {
      if (_activeQuality != null) {
        _activeQuality = null;
      } else {
        _selectedOrder = null;
        _qualityGroups = [];
        _selectedItemIds.clear();
      }
    });
  }

  List<_QualityGroup> _buildQualityGroups(List<OrderItemEntity> items) {
    final Map<String?, List<OrderItemEntity>> byQuality = {};
    for (final item in items) {
      byQuality.putIfAbsent(item.qualityName, () => []).add(item);
    }
    final keys = byQuality.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return keys
        .map((k) => _QualityGroup(
              qualityName: k,
              label: k ?? "Noma'lum sifat",
              items: byQuality[k]!,
            ))
        .toList();
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _toggleItem(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  List<OrderItemEntity> get _visibleItems {
    return (_activeQuality?.items ?? [])
        .where((i) => (i.remainingQuantity ?? i.quantity) > 0)
        .toList()
      ..sort((a, b) {
        const big = 999999;
        final wCmp = (a.sizeWidth ?? big).compareTo(b.sizeWidth ?? big);
        if (wCmp != 0) return wCmp;
        return (a.sizeLength ?? big).compareTo(b.sizeLength ?? big);
      });
  }

  void _selectAll(bool select) {
    setState(() {
      if (select) {
        for (final item in _visibleItems) {
          _selectedItemIds.add(item.id);
        }
      } else {
        _selectedItemIds.clear();
      }
    });
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  void _confirm() {
    final order = _selectedOrder;
    if (order == null) return;
    final items =
        order.items.where((i) => _selectedItemIds.contains(i.id)).toList();
    if (items.isEmpty) return;
    Navigator.of(context).pop(OrderImportResult(order: order, items: items));
  }

  // ── Title helpers ──────────────────────────────────────────────────────────

  String get _titleText {
    if (_onItemsStep) return _activeQuality?.label ?? 'Mahsulotlar';
    if (_onQualitiesStep) return 'Buyurtma #${_selectedOrder!.id}';
    return 'Buyurtmani tanlang';
  }

  String get _subtitleText {
    if (_onItemsStep) return _selectedOrder?.clientShopName ?? '';
    if (_onQualitiesStep) return 'Sifat turini tanlang';
    return "Ishlab chiqarishga ega bo'sh buyurtmalar";
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
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

          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                if (_onQualitiesStep || _onItemsStep)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: _back,
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _titleText,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_subtitleText.isNotEmpty)
                        Text(
                          _subtitleText,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

          // Step indicator
          if (!_isLoadingOrders && _ordersError == null)
            _StepIndicator(
              onOrdersStep: _onOrdersStep,
              onQualitiesStep: _onQualitiesStep,
            ),

          // Search field (step 1 only)
          if (_onOrdersStep)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: "#ID yoki do'kon nomi...",
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),

          // Content
          Flexible(child: _buildContent()),

          // Confirm button
          if (_selectedItemIds.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Import qilish (${_selectedItemIds.length} ta mahsulot)',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_onItemsStep) return _buildItemsList();
    if (_onQualitiesStep) return _buildQualitiesList();
    // Orders step
    if (_isLoadingOrders) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_ordersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Buyurtmalar yuklanmadi',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _fetchOrders(_searchCtrl.text.trim()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }
    return _buildOrdersList();
  }

  // ── Step 1: Order list ─────────────────────────────────────────────────────

  Widget _buildOrdersList() {
    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Ishlab chiqarishga tayyor buyurtma yo'q",
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final order = _orders[i];
        final isActive = _selectedOrder?.id == order.id;
        final selectedCount = isActive ? _selectedItemIds.length : 0;

        return InkWell(
          onTap: () => _selectOrder(order),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${order.items.length} ta mahsulot  ·  ${_fmtDate(order.orderDate)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          _StatusChip(status: order.status),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selectedCount > 0) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$selectedCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Step 2: Quality list ────────────────────────────────────────────────────

  Widget _buildQualitiesList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _qualityGroups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final quality = _qualityGroups[i];
        final selectedInQuality = quality.items
            .where((item) => _selectedItemIds.contains(item.id))
            .length;

        return InkWell(
          onTap: () => _selectQuality(quality),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.star_outline_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quality.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${quality.items.length} ta mahsulot',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (selectedInQuality > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$selectedInQuality',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Step 3: Item list ──────────────────────────────────────────────────────

  Widget _buildItemsList() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "Bu buyurtmada mahsulot yo'q",
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final allSelected = items.every((i) => _selectedItemIds.contains(i.id));
    final anySelected = items.any((i) => _selectedItemIds.contains(i.id));

    return Column(
      children: [
        // Select-all row
        InkWell(
          onTap: () => _selectAll(!allSelected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected ? true : anySelected ? null : false,
                  tristate: true,
                  onChanged: (_) => _selectAll(!allSelected),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  'Barchasini tanlash',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${items.where((i) => _selectedItemIds.contains(i.id)).length} / ${items.length}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final item = items[i];
              final isSelected = _selectedItemIds.contains(item.id);
              return InkWell(
                onTap: () => _toggleItem(item.id),
                child: _OrderItemTile(item: item, isSelected: isSelected),
              );
            },
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: null,
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
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Builder(builder: (context) {
                  final parts = <String>[
                    if (item.colorName != null) item.colorName!.toUpperCase(),
                    if (item.sizeLength != null && item.sizeWidth != null)
                      '${item.sizeWidth}×${item.sizeLength}',
                    if (item.qualityName != null) item.qualityName!,
                  ];
                  if (parts.isEmpty) return const SizedBox.shrink();
                  return Text(
                    parts.join('  ·  '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _QtyBadge(
                label: 'Qoldi',
                value: '$remaining ta',
                color: remaining > 0 ? AppColors.primary : AppColors.error,
                bold: true,
              ),
              if (item.remainingQuantity != null) ...[
                const SizedBox(height: 2),
                _QtyBadge(
                  label: 'Jami',
                  value: '${item.quantity} ta',
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final bool onOrdersStep;
  final bool onQualitiesStep;
  const _StepIndicator({
    required this.onOrdersStep,
    required this.onQualitiesStep,
  });

  @override
  Widget build(BuildContext context) {
    final onItemsStep = !onOrdersStep && !onQualitiesStep;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          _StepDot(
            index: 1,
            label: 'Buyurtma',
            active: onOrdersStep,
            done: !onOrdersStep,
          ),
          _StepLine(done: !onOrdersStep),
          _StepDot(
            index: 2,
            label: 'Sifat',
            active: onQualitiesStep,
            done: onItemsStep,
          ),
          _StepLine(done: onItemsStep),
          _StepDot(
            index: 3,
            label: 'Mahsulot',
            active: onItemsStep,
            done: false,
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool active;
  final bool done;

  const _StepDot({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primary
        : done
            ? AppColors.success
            : AppColors.divider;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded, size: 13, color: color)
                : Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool done;
  const _StepLine({required this.done});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.only(bottom: 16),
        color: done ? AppColors.success : AppColors.divider,
      ),
    );
  }
}

// ── Qty badge ──────────────────────────────────────────────────────────────────

class _QtyBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _QtyBadge({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ],
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
