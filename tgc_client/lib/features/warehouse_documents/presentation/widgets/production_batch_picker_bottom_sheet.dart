import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../production/domain/entities/production_batch_entity.dart';
import '../../../production/domain/entities/production_batch_item_entity.dart';
import '../../../production/domain/usecases/get_production_batch_usecase.dart';
import '../../../production/domain/usecases/get_production_batches_usecase.dart';

/// Result returned by [ProductionBatchPickerBottomSheet.show].
class BatchImportResult {
  final ProductionBatchEntity batch;
  final List<ProductionBatchItemEntity> items;
  const BatchImportResult({required this.batch, required this.items});
}

/// Two-step bottom sheet for importing items from a production batch into a
/// warehouse document:
///   1. Pick a batch from a searchable list (completed/in_progress batches).
///   2. Multi-select items by their [producedQuantity].
///
/// Returns [BatchImportResult] or null if dismissed.
class ProductionBatchPickerBottomSheet extends StatefulWidget {
  const ProductionBatchPickerBottomSheet({super.key});

  static Future<BatchImportResult?> show(BuildContext context) {
    return showModalBottomSheet<BatchImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ProductionBatchPickerBottomSheet(),
    );
  }

  @override
  State<ProductionBatchPickerBottomSheet> createState() =>
      _ProductionBatchPickerBottomSheetState();
}

class _ProductionBatchPickerBottomSheetState
    extends State<ProductionBatchPickerBottomSheet> {
  // ── Step 1 state ──────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<ProductionBatchEntity> _batches = [];
  bool _isLoadingBatches = true;
  String? _batchesError;

  // ── Step 2 state ──────────────────────────────────────────────────────────
  ProductionBatchEntity? _selectedBatch;
  List<ProductionBatchItemEntity> _batchItems = [];
  bool _isLoadingItems = false;
  String? _itemsError;
  final Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _fetchBatches('');
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
      _fetchBatches(query.trim());
    });
  }

  Future<void> _fetchBatches(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoadingBatches = true;
      _batchesError = null;
    });
    final useCase = sl<GetProductionBatchesUseCase>();
    // Only completed and in_progress batches have produced quantities.
    final result = await useCase(
      perPage: 100,
      excludeWarehouseReceived: true,
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _batchesError = failure.toString();
        _isLoadingBatches = false;
      }),
      (page) {
        var data = page.data
            .where((b) => b.status == 'completed' || b.status == 'in_progress')
            .toList();
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          data = data
              .where((b) =>
                  '#${b.id}'.contains(q) ||
                  b.batchTitle.toLowerCase().contains(q) ||
                  (b.machine?.name.toLowerCase().contains(q) ?? false))
              .toList();
        }
        setState(() {
          _batches = data;
          _isLoadingBatches = false;
        });
      },
    );
  }

  Future<void> _selectBatch(ProductionBatchEntity batch) async {
    setState(() {
      _selectedBatch = batch;
      _batchItems = [];
      _selectedItemIds.clear();
      _isLoadingItems = true;
      _itemsError = null;
    });

    final useCase = sl<GetProductionBatchUseCase>();
    final result = await useCase(
      batch.id,
      excludeWarehouseReceived: true,
    );
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _itemsError = failure.toString();
        _isLoadingItems = false;
      }),
      (detail) {
        final items = detail.items
            .where((i) => (i.producedQuantity ?? 0) > 0)
            .toList();
        setState(() {
          _batchItems = items;
          _isLoadingItems = false;
          // Pre-select all items
          for (final item in items) {
            _selectedItemIds.add(item.id);
          }
        });
      },
    );
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
    final batch = _selectedBatch;
    if (batch == null) return;
    final items =
        _batchItems.where((i) => _selectedItemIds.contains(i.id)).toList();
    if (items.isEmpty) return;
    Navigator.of(context).pop(BatchImportResult(batch: batch, items: items));
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
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 12),
            child: Row(
              children: [
                if (_selectedBatch != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => setState(() {
                      _selectedBatch = null;
                      _batchItems = [];
                      _selectedItemIds.clear();
                    }),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                if (_selectedBatch != null) const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedBatch == null
                            ? 'Partiyani tanlash'
                            : '#${_selectedBatch!.id} — mahsulotlarni tanlash',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_selectedBatch == null)
                        Text(
                          'Tugatilgan yoki davom etayotgan partiyalar',
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

          if (_selectedBatch == null) ...[
            // ── Step 1: batch list ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: '#ID, partiya nomi yoki stanok...',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Flexible(
              child: _isLoadingBatches
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _batchesError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Partiyalar yuklanmadi',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        )
                      : _batches.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Tayyor partiya topilmadi',
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
                              itemCount: _batches.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final batch = _batches[i];
                                return InkWell(
                                  onTap: () => _selectBatch(batch),
                                  child: _BatchTile(batch: batch),
                                );
                              },
                            ),
            ),
          ] else ...[
            // ── Step 2: item multi-select ──────────────────────────────
            if (_isLoadingItems)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_itemsError != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Mahsulotlar yuklanmadi',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.error),
                    ),
                  ),
                ),
              )
            else if (_batchItems.isEmpty)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Bu partiyada ishlab chiqarilgan mahsulot yo\'q'),
                  ),
                ),
              )
            else
              Flexible(
                child: Column(
                  children: [
                    // Select all toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            'Barchasi',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          Switch(
                            value: _batchItems.every(
                                (i) => _selectedItemIds.contains(i.id)),
                            onChanged: (val) {
                              setState(() {
                                if (val) {
                                  for (final item in _batchItems) {
                                    _selectedItemIds.add(item.id);
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
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                        itemCount: _batchItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = _batchItems[i];
                          final isSelected =
                              _selectedItemIds.contains(item.id);
                          return InkWell(
                            onTap: () => _toggleItem(item.id),
                            child: _BatchItemTile(
                              item: item,
                              isSelected: isSelected,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Confirm button
            if (!_isLoadingItems && _itemsError == null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: _selectedItemIds.isEmpty ? null : _confirm,
                    child: Text(
                        'Import (${_selectedItemIds.length} ta mahsulot)'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Batch tile ────────────────────────────────────────────────────────────────

class _BatchTile extends StatelessWidget {
  final ProductionBatchEntity batch;
  const _BatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (batch.status) {
      'completed' => AppColors.success,
      'in_progress' => AppColors.primary,
      _ => AppColors.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#${batch.id}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
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
                  batch.batchTitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (batch.machine != null) ...[
                      const Icon(
                        Icons.precision_manufacturing_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        batch.machine!.name,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        batch.statusLabel,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${batch.itemsCount} ta mahsulot',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                _fmtDate(batch.completedDatetime ?? batch.updatedAt),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ── Batch item tile ───────────────────────────────────────────────────────────

class _BatchItemTile extends StatelessWidget {
  final ProductionBatchItemEntity item;
  final bool isSelected;

  const _BatchItemTile({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final produced = item.producedQuantity ?? 0;
    final defect = item.defectQuantity ?? 0;
    final net = produced - defect;

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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (item.colorName != null) ...[
                      Text(
                        item.colorName!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (item.sizeLength != null && item.sizeWidth != null)
                      Text(
                        '${item.sizeLength}×${item.sizeWidth}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _QtyChip(
                label: 'Ishlab chiqarildi',
                value: '$produced dona',
                color: AppColors.success,
              ),
              if (defect > 0) ...[
                const SizedBox(height: 2),
                _QtyChip(
                  label: 'Brak',
                  value: '$defect dona',
                  color: AppColors.error,
                ),
              ],
              if (net != produced) ...[
                const SizedBox(height: 2),
                _QtyChip(
                  label: 'Sof',
                  value: '$net dona',
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QtyChip({
    required this.label,
    required this.value,
    required this.color,
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
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
