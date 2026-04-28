import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../domain/entities/product_size_entity.dart';
import '../../domain/entities/product_type_entity.dart';

class _SizePickerData {
  final List<ProductSizeEntity> sizes;
  final List<ProductTypeEntity> types;

  const _SizePickerData({required this.sizes, required this.types});
}

/// In-memory cache: `null` key = all sizes+types; int key = filtered by type.
/// Lives for the app session so repeated opens skip the network round-trip.
final _cache = <Object?, _SizePickerData>{};

/// A bottom sheet that loads sizes for a given [productTypeId] and lets
/// the user select one.  When [productTypeId] is null, all sizes are shown
/// grouped by type.  Returns the chosen [ProductSizeEntity] or null.
class ProductSizePickerSheet extends StatefulWidget {
  final int? productTypeId;

  const ProductSizePickerSheet({super.key, this.productTypeId});

  static Future<ProductSizeEntity?> show(
    BuildContext context, {
    int? productTypeId,
  }) {
    return showModalBottomSheet<ProductSizeEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductSizePickerSheet(productTypeId: productTypeId),
    );
  }

  /// Clears the in-memory cache (e.g. after adding/deleting a size on the backend).
  static void clearCache([int? productTypeId]) {
    if (productTypeId != null) {
      _cache.remove(productTypeId);
    } else {
      _cache.clear();
    }
  }

  @override
  State<ProductSizePickerSheet> createState() => _ProductSizePickerSheetState();
}

class _ProductSizePickerSheetState extends State<ProductSizePickerSheet> {
  late Future<_SizePickerData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SizePickerData> _load() async {
    final cacheKey = widget.productTypeId as Object?;
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final ds = sl<ProductRemoteDataSource>();
    late _SizePickerData data;
    if (widget.productTypeId != null) {
      final sizes = await ds.getProductSizes(productTypeId: widget.productTypeId);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            'O\'lchamni tanlang',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
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
                    return _SizeWrap(sizes: data.sizes, onTap: _pop);
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
                          _SizeWrap(sizes: entry.value, onTap: _pop),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _pop(ProductSizeEntity size) => Navigator.of(context).pop(size);
}

class _SizeWrap extends StatelessWidget {
  final List<ProductSizeEntity> sizes;
  final void Function(ProductSizeEntity) onTap;

  const _SizeWrap({required this.sizes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: sizes.map((size) {
        return InkWell(
          onTap: () => onTap(size),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
            child: Text(
              size.dimensions,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
