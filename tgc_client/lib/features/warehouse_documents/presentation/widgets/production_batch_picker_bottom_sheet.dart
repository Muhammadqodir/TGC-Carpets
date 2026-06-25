import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/warehouse_import_entities.dart';
import '../../domain/usecases/get_import_clients_usecase.dart';
import '../../domain/usecases/get_import_items_usecase.dart';
import '../../domain/usecases/get_import_qualities_usecase.dart';
import 'warehouse_document_form_controller.dart';
import 'warehouse_item_row.dart';

/// Result returned by [ProductionBatchPickerBottomSheet.show].
class BatchImportResult {
  final List<BatchItemImportEntry> entries;
  const BatchImportResult({required this.entries});
}

// ── Navigation step ────────────────────────────────────────────────────────────

enum _Step { clients, qualities, items }

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

class _ProductionBatchPickerBottomSheetState
    extends State<ProductionBatchPickerBottomSheet> {
  // ── Loading ────────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // ── Navigation ────────────────────────────────────────────────────────────
  _Step _step = _Step.clients;

  // ── Data per step ─────────────────────────────────────────────────────────
  List<ImportClientEntity> _clients = [];
  ImportClientEntity? _activeClient;

  List<ImportQualityEntity> _qualities = [];
  ImportQualityEntity? _activeQuality;

  List<ImportItemEntity> _items = [];

  // ── Selection ────────────────────────────────────────────────────────────
  final Set<int> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadClients() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await sl<GetImportClientsUseCase>()();

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = "Mijozlar yuklanmadi: ${failure.message}";
        _loading = false;
      }),
      (clients) => setState(() {
        _clients = clients;
        _loading = false;
      }),
    );
  }

  Future<void> _loadQualities(ImportClientEntity client) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _activeClient = client;
      _step = _Step.qualities;
    });

    final result = await sl<GetImportQualitiesUseCase>()(clientId: client.id);

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = "Sifatlar yuklanmadi: ${failure.message}";
        _loading = false;
      }),
      (qualities) => setState(() {
        _qualities = qualities;
        _loading = false;
      }),
    );
  }

  Future<void> _loadItems(ImportQualityEntity quality) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _activeQuality = quality;
      _step = _Step.items;
    });

    final result = await sl<GetImportItemsUseCase>()(
      clientId: _activeClient!.id,
      qualityName: quality.qualityName,
    );

    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _error = "Mahsulotlar yuklanmadi: ${failure.message}";
        _loading = false;
      }),
      (items) => setState(() {
        _items = items;
        _loading = false;
      }),
    );
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _back() {
    setState(() {
      if (_step == _Step.items) {
        _step = _Step.qualities;
        _activeQuality = null;
        _items = [];
      } else if (_step == _Step.qualities) {
        _step = _Step.clients;
        _activeClient = null;
        _qualities = [];
      }
      _error = null;
    });
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

  void _selectAll(bool select) {
    setState(() {
      for (final item in _items) {
        if (select) {
          _selectedItemIds.add(item.id);
        } else {
          _selectedItemIds.remove(item.id);
        }
      }
    });
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  void _confirm() {
    final entries = _items
        .where((item) => _selectedItemIds.contains(item.id))
        .map((item) => BatchItemImportEntry(
              item: item,
              batchId: item.batchId,
              batchTitle: item.batchTitle,
              quantity: max(1, item.available),
            ))
        .toList();

    if (entries.isEmpty) return;
    Navigator.of(context).pop(BatchImportResult(entries: entries));
  }

  // ── Title helpers ──────────────────────────────────────────────────────────

  String get _titleText => switch (_step) {
        _Step.clients   => 'Mijozni tanlang',
        _Step.qualities => _activeClient?.displayName ?? 'Sifatni tanlang',
        _Step.items     => _activeQuality?.qualityName ?? 'Mahsulotlar',
      };

  String get _subtitleText => switch (_step) {
        _Step.clients   => 'Tayyor mahsuloti mavjud mijozlar',
        _Step.qualities => 'Sifat turini tanlang',
        _Step.items     => _activeClient?.displayName ?? '',
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
                if (_step != _Step.clients)
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
          if (!_loading && _error == null)
            _StepIndicator(step: _step),

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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: switch (_step) {
                  _Step.clients   => _loadClients,
                  _Step.qualities => () => _loadQualities(_activeClient!),
                  _Step.items     => () => _loadItems(_activeQuality!),
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    return switch (_step) {
      _Step.clients   => _buildClientsList(),
      _Step.qualities => _buildQualitiesList(),
      _Step.items     => _buildItemsList(),
    };
  }

  // ── Step 1: Clients ────────────────────────────────────────────────────────

  Widget _buildClientsList() {
    if (_clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Tayyor mahsulotli mijozlar topilmadi',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _clients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final client = _clients[i];
        return InkWell(
          onTap: () => _loadQualities(client),
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
                  child: const Icon(
                    Icons.storefront_rounded,
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
                        client.shopName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        client.region,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      if (client.itemCount > 0) ...[
                        const SizedBox(height: 1),
                        Text(
                          '${client.itemCount} ta mahsulot',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
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
    if (_qualities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Bu mijoz uchun tayyor mahsulotlar topilmadi',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: _qualities.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final quality = _qualities[i];
        return InkWell(
          onTap: () => _loadItems(quality),
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
                        quality.qualityName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${quality.itemCount} ta mahsulot',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
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
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Mahsulotlar topilmadi',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final allSelected = _items.every((i) => _selectedItemIds.contains(i.id));
    final anySelected = _items.any((i) => _selectedItemIds.contains(i.id));

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
                  '${_items.where((i) => _selectedItemIds.contains(i.id)).length} / ${_items.length}',
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
            itemCount: _items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _buildItemTile(_items[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(ImportItemEntity item) {
    final isSelected = _selectedItemIds.contains(item.id);
    final matchingRows =
        widget.existingRows.where((r) => r.sourceBatchItemId == item.id);
    final inRow = matchingRows.isEmpty
        ? 0
        : (int.tryParse(matchingRows.first.quantityCtrl.text) ?? 0);
    final available = (item.available - inRow).clamp(0, item.available);

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
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.batchTitle,
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
            label: 'Mijoz',
            active: step == _Step.clients,
            done: step != _Step.clients,
          ),
          _StepLine(done: step != _Step.clients),
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
