import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../products/data/datasources/product_remote_datasource.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';

class _SizePickerData {
  final List<ProductSizeEntity> sizes;
  final List<ProductTypeEntity> types;

  const _SizePickerData({required this.sizes, required this.types});
}

/// In-memory cache: stores all sizes+types to skip network round-trips.
final _cache = <Object?, _SizePickerData>{};

/// A bottom sheet for multi-selecting sizes in the add order matrix view.
///
/// Features:
/// - Toggle selection (can select/deselect multiple sizes)
/// - Shows already selected sizes
/// - Doesn't auto-close on tap
/// - Returns all selected sizes on "Apply" button press
class OrderProductSizeMultiPickerSheet extends StatefulWidget {
  /// Currently selected size IDs (to show as initially selected)
  final Set<int> alreadySelectedSizeIds;

  /// Optional: filter by product type ID
  final int? productTypeId;

  const OrderProductSizeMultiPickerSheet({
    super.key,
    this.alreadySelectedSizeIds = const {},
    this.productTypeId,
  });

  static Future<List<ProductSizeEntity>?> show(
    BuildContext context, {
    Set<int> alreadySelectedSizeIds = const {},
    int? productTypeId,
  }) {
    return showModalBottomSheet<List<ProductSizeEntity>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderProductSizeMultiPickerSheet(
        alreadySelectedSizeIds: alreadySelectedSizeIds,
        productTypeId: productTypeId,
      ),
    );
  }

  /// Clears the in-memory cache (e.g. after adding/deleting a size).
  static void clearCache() => _cache.clear();

  @override
  State<OrderProductSizeMultiPickerSheet> createState() =>
      _OrderProductSizeMultiPickerSheetState();
}

class _OrderProductSizeMultiPickerSheetState
    extends State<OrderProductSizeMultiPickerSheet> {
  late Future<_SizePickerData> _future;
  late Set<int> _selectedSizeIds;

  @override
  void initState() {
    super.initState();
    _selectedSizeIds = Set.from(widget.alreadySelectedSizeIds);
    _future = _load();
  }

  Future<_SizePickerData> _load() async {
    final cacheKey = widget.productTypeId as Object?;
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final ds = sl<ProductRemoteDataSource>();
    late _SizePickerData data;
    if (widget.productTypeId != null) {
      final sizes =
          await ds.getProductSizes(productTypeId: widget.productTypeId);
      data = _SizePickerData(sizes: sizes, types: const []);
    } else {
      final results = await Future.wait([
        ds.getProductSizes(),
        ds.getProductTypes(),
      ]);
      data = _SizePickerData(
        sizes: results[0] as List<ProductSizeEntity>,
        types: results[1] as List<ProductTypeEntity>,
      );
    }
    _cache[cacheKey] = data;
    return data;
  }

  void _toggleSize(int sizeId) {
    // Don't allow toggling already added sizes
    if (widget.alreadySelectedSizeIds.contains(sizeId)) return;
    
    setState(() {
      if (_selectedSizeIds.contains(sizeId)) {
        _selectedSizeIds.remove(sizeId);
      } else {
        _selectedSizeIds.add(sizeId);
      }
    });
  }

  void _apply(_SizePickerData data) {
    final selectedSizes = data.sizes
        .where((size) => _selectedSizeIds.contains(size.id))
        .toList();
    Navigator.of(context).pop(selectedSizes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'O\'lchamlarni tanlang',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (_selectedSizeIds.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedSizeIds.length} tanlangan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Sizes list
          Expanded(
            child: SingleChildScrollView(
              child: FutureBuilder<_SizePickerData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.sizes.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'O\'lchamlar topilmadi.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data!;

                  // Flat list when a specific type is pre-selected
                  if (widget.productTypeId != null) {
                    return _SizeMultiSelectWrap(
                      sizes: data.sizes,
                      selectedSizeIds: _selectedSizeIds,
                      onToggle: _toggleSize,
                      alreadyAddedIds: widget.alreadySelectedSizeIds,
                    );
                  }

                  // Grouped by type when showing all
                  final typeMap = {for (final t in data.types) t.id: t.type};
                  final grouped = <int, List<ProductSizeEntity>>{};
                  for (final s in data.sizes) {
                    grouped.putIfAbsent(s.productTypeId, () => []).add(s);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: grouped.entries.map((entry) {
                      final typeName =
                          typeMap[entry.key] ?? 'Tur #${entry.key}';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppColors.divider,
                                    thickness: 1,
                                    endIndent: 8,
                                  ),
                                ),
                                Text(
                                  typeName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: AppColors.divider,
                                    thickness: 1,
                                    indent: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _SizeMultiSelectWrap(
                            sizes: entry.value,
                            selectedSizeIds: _selectedSizeIds,
                            onToggle: _toggleSize,
                            alreadyAddedIds: widget.alreadySelectedSizeIds,
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Apply button
          FutureBuilder<_SizePickerData>(
            future: _future,
            builder: (context, snapshot) {
              final hasData = snapshot.hasData;
              return FilledButton(
                onPressed: hasData && _selectedSizeIds.isNotEmpty
                    ? () => _apply(snapshot.data!)
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Qo\'llash'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SizeMultiSelectWrap extends StatelessWidget {
  final List<ProductSizeEntity> sizes;
  final Set<int> selectedSizeIds;
  final Set<int> alreadyAddedIds;
  final void Function(int) onToggle;

  const _SizeMultiSelectWrap({
    required this.sizes,
    required this.selectedSizeIds,
    required this.onToggle,
    required this.alreadyAddedIds,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: sizes.map((size) {
        final isSelected = selectedSizeIds.contains(size.id);
        final wasAlreadyAdded = alreadyAddedIds.contains(size.id);
        final showAsSelected = isSelected || wasAlreadyAdded;

        return InkWell(
          onTap: wasAlreadyAdded ? null : () => onToggle(size.id),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: showAsSelected ? AppColors.primary : AppColors.divider,
                width: showAsSelected ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
              color: showAsSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showAsSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      size: 14,
                      color: AppColors.primary,
                      strokeWidth: 3.5,
                    ),
                  ),
                Text(
                  size.dimensions,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: showAsSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight:
                            showAsSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
