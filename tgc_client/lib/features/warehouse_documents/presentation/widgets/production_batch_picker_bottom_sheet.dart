import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../production/domain/entities/production_batch_entity.dart';
import '../../../production/domain/entities/production_batch_item_entity.dart';
import '../../../production/domain/usecases/get_production_batch_usecase.dart';
import '../../../production/domain/usecases/get_production_batches_usecase.dart';
import 'warehouse_document_form_controller.dart';
import 'warehouse_item_row.dart';

/// Result returned by [ProductionBatchPickerBottomSheet.show].
class BatchImportResult {
  final List<BatchItemImportEntry> entries;
  const BatchImportResult({required this.entries});
}

/// A ready batch item together with its batch context, used for order-grouped
/// display and selection.
class _ReadyItem {
  final ProductionBatchItemEntity item;
  final ProductionBatchEntity batch;
  /// Available = produced - warehouseReceived (clamped ≥ 0).
  final int available;

  const _ReadyItem({
    required this.item,
    required this.batch,
    required this.available,
  });
}

/// Bottom sheet that shows all ready production batch items grouped by order.
/// The user multi-selects items across any order/batch and confirms once.
///
/// Returns [BatchImportResult] or null if dismissed.
class ProductionBatchPickerBottomSheet extends StatefulWidget {
  final List<WarehouseItemRow> existingRows;

  const ProductionBatchPickerBottomSheet({
    super.key,
    this.existingRows = const [],
  });

  static Future<BatchImportResult?> show(
    BuildContext context, {
    List<WarehouseItemRow> existingRows = const [],
  }) {
    return showModalBottomSheet<BatchImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ProductionBatchPickerBottomSheet(
        existingRows: existingRows,
      ),
    );
  }

  @override
  State<ProductionBatchPickerBottomSheet> createState() =>
      _ProductionBatchPickerBottomSheetState();
}

// ── Data models ───────────────────────────────────────────────────────────────

class _OrderGroup {
  final int? orderId; // null = stock items
  final String label;
  final String? shopName;
  final String? region;
  final List<_ReadyItem> items;

  _OrderGroup({
    required this.orderId,
    required this.label,
    this.shopName,
    this.region,
    required this.items,
  });
}

class _QualityGroup {
  final String? qualityName;
  final String label;
  final List<_ReadyItem> items;

  _QualityGroup({
    required this.qualityName,
    required this.label,
    required this.items,
  });
}

// ── Navigation step ────────────────────────────────────────────────────────────

enum _Step { orders, qualities, items }

class _ProductionBatchPickerBottomSheetState
    extends State<ProductionBatchPickerBottomSheet> {
  // ── Loading ────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<_OrderGroup> _orderGroups = [];

  // ── Navigation ────────────────────────────────────────────────────────────
  _Step _step = _Step.orders;
  _OrderGroup? _activeOrder;
  List<_QualityGroup> _qualityGroups = [];
  _QualityGroup? _activeQuality;

  // ── Selection (no default) ────────────────────────────────────────────────
  final Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final batchesResult = await sl<GetProductionBatchesUseCase>()(
      perPage: 100,
      excludeWarehouseReceived: true,
    );

    if (!mounted) return;

    final batches = batchesResult.fold<List<ProductionBatchEntity>?>(
      (_) => null,
      (page) => page.data,
    );

    if (batches == null) {
      setState(() {
        _error = 'Partiyalar yuklanmadi';
        _loading = false;
      });
      return;
    }

    final detailResults = await Future.wait(
      batches.map(
        (b) => sl<GetProductionBatchUseCase>()(
          b.id,
          excludeWarehouseReceived: true,
        ),
      ),
    );

    if (!mounted) return;

    final allItems = <_ReadyItem>[];
    for (int i = 0; i < batches.length; i++) {
      detailResults[i].fold((_) {}, (detail) {
        for (final item in detail.items) {
          final available = ((item.producedQuantity ?? 0) -
                  (item.warehouseReceivedQuantity ?? 0))
              .clamp(0, item.producedQuantity ?? 0);
          if (available > 0) {
            allItems.add(
              _ReadyItem(item: item, batch: detail, available: available),
            );
          }
        }
      });
    }

    final Map<int?, List<_ReadyItem>> byOrder = {};
    for (final ri in allItems) {
      byOrder.putIfAbsent(ri.item.sourceOrderId, () => []).add(ri);
    }

    final orderKeys = byOrder.keys.where((k) => k != null).toList()
      ..sort((a, b) => a!.compareTo(b!));

    final groups = <_OrderGroup>[];
    for (final orderId in orderKeys) {
      final items = byOrder[orderId]!;
      final first = items.first;
      groups.add(_OrderGroup(
        orderId: orderId,
        label: 'Buyurtma #$orderId',
        shopName: first.item.sourceClientShopName,
        region: first.item.sourceClientRegion,
        items: items,
      ));
    }

    if (byOrder.containsKey(null)) {
      groups.add(_OrderGroup(
        orderId: null,
        label: 'Ombor uchun (stok)',
        items: byOrder[null]!,
      ));
    }

    setState(() {
      _orderGroups = groups;
      _loading = false;
    });
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _selectOrder(_OrderGroup order) {
    setState(() {
      _activeOrder = order;
      _qualityGroups = _buildQualityGroups(order.items);
      _step = _Step.qualities;
    });
  }

  void _selectQuality(_QualityGroup quality) {
    setState(() {
      _activeQuality = quality;
      _step = _Step.items;
    });
  }

  void _back() {
    setState(() {
      if (_step == _Step.items) {
        _step = _Step.qualities;
        _activeQuality = null;
      } else if (_step == _Step.qualities) {
        _step = _Step.orders;
        _activeOrder = null;
        _qualityGroups = [];
      }
    });
  }

  List<_QualityGroup> _buildQualityGroups(List<_ReadyItem> items) {
    final Map<String?, List<_ReadyItem>> byQuality = {};
    for (final ri in items) {
      byQuality.putIfAbsent(ri.item.qualityName, () => []).add(ri);
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

  // ── Selection helpers ──────────────────────────────────────────────────────

  void _toggleItem(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _selectAllInQuality(_QualityGroup quality, bool select) {
    setState(() {
      for (final ri in quality.items) {
        if (select) {
          _selectedItemIds.add(ri.item.id);
        } else {
          _selectedItemIds.remove(ri.item.id);
        }
      }
    });
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  void _confirm() {
    final entries = <BatchItemImportEntry>[];
    for (final group in _orderGroups) {
      for (final ri in group.items) {
        if (!_selectedItemIds.contains(ri.item.id)) continue;
        entries.add(BatchItemImportEntry(
          item: ri.item,
          batchId: ri.batch.id,
          batchTitle: ri.batch.batchTitle,
          quantity: max(1, ri.available),
        ));
      }
    }
    if (entries.isEmpty) return;
    Navigator.of(context).pop(BatchImportResult(entries: entries));
  }

  // ── Title helpers ──────────────────────────────────────────────────────────

  String get _titleText => switch (_step) {
        _Step.orders    => 'Buyurtmani tanlang',
        _Step.qualities => _activeOrder?.label ?? 'Sifatni tanlang',
        _Step.items     => _activeQuality?.label ?? 'Mahsulotlar',
      };

  String get _subtitleText => switch (_step) {
        _Step.orders    => 'Tayyor mahsulotlar mavjud buyurtmalar',
        _Step.qualities => 'Sifat turini tanlang',
        _Step.items     => _activeOrder?.label ?? '',
      };

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
                if (_step != _Step.orders)
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

          // Step indicator (only when data is loaded)
          if (!_loading && _error == null && _orderGroups.isNotEmpty)
            _StepIndicator(step: _step),

          // Content
          Flexible(child: _buildContent()),

          // Confirm button — visible whenever items are selected
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
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    return switch (_step) {
      _Step.orders    => _buildOrdersList(),
      _Step.qualities => _buildQualitiesList(),
      _Step.items     => _buildItemsList(),
    };
  }

  // ── Step 1: Orders ─────────────────────────────────────────────────────────

  Widget _buildOrdersList() {
    if (_orderGroups.isEmpty) {
      return Center(
        child: Text(
          'Tayyor mahsulotlar topilmadi',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _orderGroups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final group = _orderGroups[i];
        final selectedInGroup = group.items
            .where((ri) => _selectedItemIds.contains(ri.item.id))
            .length;
        final isOrder = group.orderId != null;

        return InkWell(
          onTap: () => _selectOrder(group),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        (isOrder ? AppColors.primary : AppColors.textSecondary)
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isOrder
                        ? Icons.receipt_long_rounded
                        : Icons.inventory_2_outlined,
                    size: 20,
                    color: isOrder
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (group.shopName != null || group.region != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          [group.shopName, group.region]
                              .whereType<String>()
                              .join(', '),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 1),
                      Text(
                        '${group.items.length} ta mahsulot',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (selectedInGroup > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$selectedInGroup',
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

  // ── Step 2: Qualities ──────────────────────────────────────────────────────

  Widget _buildQualitiesList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _qualityGroups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final quality = _qualityGroups[i];
        final selectedInQuality = quality.items
            .where((ri) => _selectedItemIds.contains(ri.item.id))
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

  // ── Step 3: Items ──────────────────────────────────────────────────────────

  Widget _buildItemsList() {
    final quality = _activeQuality!;
    final allSelected =
        quality.items.every((ri) => _selectedItemIds.contains(ri.item.id));
    final anySelected =
        quality.items.any((ri) => _selectedItemIds.contains(ri.item.id));

    return Column(
      children: [
        // Select-all row
        InkWell(
          onTap: () => _selectAllInQuality(quality, !allSelected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected
                      ? true
                      : anySelected
                          ? null
                          : false,
                  tristate: true,
                  onChanged: (_) =>
                      _selectAllInQuality(quality, !allSelected),
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
                  '${quality.items.where((ri) => _selectedItemIds.contains(ri.item.id)).length} / ${quality.items.length}',
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
            itemCount: quality.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _buildItemTile(quality.items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(_ReadyItem ri) {
    final item = ri.item;
    final isSelected = _selectedItemIds.contains(item.id);
    final matchingRows =
        widget.existingRows.where((r) => r.sourceBatchItemId == item.id);
    final inRow = matchingRows.isEmpty
        ? 0
        : (int.tryParse(matchingRows.first.quantityCtrl.text) ?? 0);
    final available = (ri.available - inRow).clamp(0, ri.available);

    return InkWell(
      onTap: () => _toggleItem(item.id),
      child: Padding(
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
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.colorName != null) ...[
                        Text(
                          item.colorName!.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (item.sizeLength != null && item.sizeWidth != null)
                        Text(
                          '${item.sizeWidth}x${item.sizeLength}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ri.batch.batchTitle,
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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _QtyBadge(
                  label: 'Ishlab chiqarildi',
                  value: '${item.producedQuantity ?? 0}',
                  color: AppColors.success,
                ),
                if ((item.warehouseReceivedQuantity ?? 0) > 0) ...[
                  const SizedBox(height: 2),
                  _QtyBadge(
                    label: 'Qabul qilingan',
                    value: '${item.warehouseReceivedQuantity}',
                    color: AppColors.textSecondary,
                  ),
                ],
                if (inRow > 0) ...[
                  const SizedBox(height: 2),
                  _QtyBadge(
                    label: "Qo'shilgan",
                    value: '$inRow',
                    color: AppColors.warning,
                  ),
                ],
                const SizedBox(height: 2),
                _QtyBadge(
                  label: 'Mavjud',
                  value: '$available',
                  color: available > 0 ? AppColors.primary : AppColors.error,
                  bold: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final _Step step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          _StepDot(
            index: 1,
            label: 'Buyurtma',
            active: step == _Step.orders,
            done: step != _Step.orders,
          ),
          _StepLine(done: step != _Step.orders),
          _StepDot(
            index: 2,
            label: 'Sifat',
            active: step == _Step.qualities,
            done: step == _Step.items,
          ),
          _StepLine(done: step == _Step.items),
          _StepDot(
            index: 3,
            label: 'Mahsulot',
            active: step == _Step.items,
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
