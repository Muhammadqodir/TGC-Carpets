import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/search_picker_bottom_sheet.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../domain/entities/product_color_entity.dart';
import '../../domain/entities/product_edge_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../../product_attributes/data/datasources/product_attributes_remote_datasource.dart';

/// Holds the product, the exact colour, and the edge the user selected.
class ProductPickerResult {
  final ProductEntity product;
  final ProductColorEntity? color;
  final ProductEdgeEntity? edge;

  const ProductPickerResult({required this.product, this.color, this.edge});
}

/// Three-step picker: product → colour → edge (default R).
///
/// Returns [ProductPickerResult] or null if the user dismisses any step.
class ProductPickerBottomSheet {
  ProductPickerBottomSheet._();

  static Future<ProductPickerResult?> show(BuildContext context) async {
    // ── Step 1: search & pick product ───────────────────────────────────────
    final product = await SearchPickerBottomSheet.show<ProductEntity>(
      context,
      title: 'Mahsulot tanlash',
      searchHint: 'Nom yoki tur...',
      onSearch: (query) async {
        final datasource = sl<ProductRemoteDataSource>();
        final result = await datasource.getProducts(
          search: query.isEmpty ? null : query,
          status: 'active',
          perPage: 30,
        );
        return result.data;
      },
      itemBuilder: (context, product) => _ProductPickerTile(product: product),
      emptyText: 'Mahsulot topilmadi.',
      errorText: 'Mahsulotlarni yuklashda xatolik.',
    );

    if (product == null) return null;

    // ── Step 2: pick colour ──────────────────────────────────────────────────
    ProductColorEntity? color;
    if (product.productColors.isEmpty) {
      color = null;
    } else if (product.productColors.length == 1) {
      color = product.productColors.first;
    } else {
      // ignore: use_build_context_synchronously
      color = await _ColorPickerSheet.show(context, product);
      if (color == null) return null;
    }

    // ── Step 3: pick edge (default R) ────────────────────────────────────────
    // ignore: use_build_context_synchronously
    final edge = await _EdgePickerSheet.show(context);
    if (edge == null) return null;

    return ProductPickerResult(product: product, color: color, edge: edge);
  }
}

// ── Colour picker sheet (step 2) ─────────────────────────────────────────────

class _ColorPickerSheet extends StatelessWidget {
  final ProductEntity product;

  const _ColorPickerSheet({required this.product});

  static Future<ProductColorEntity?> show(
    BuildContext context,
    ProductEntity product,
  ) {
    return showModalBottomSheet<ProductColorEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ColorPickerSheet(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'Rang tanlang',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          ...product.productColors.map((pc) => _ColorTile(color: pc)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final ProductColorEntity color;

  const _ColorTile({required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(color),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: color.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: color.imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                color.colorName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.palette_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
      );
}

// ── Edge picker sheet (step 3) ────────────────────────────────────────────────

class _EdgePickerSheet extends StatefulWidget {
  const _EdgePickerSheet();

  static Future<ProductEdgeEntity?> show(BuildContext context) {
    return showModalBottomSheet<ProductEdgeEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EdgePickerSheet(),
    );
  }

  @override
  State<_EdgePickerSheet> createState() => _EdgePickerSheetState();
}

class _EdgePickerSheetState extends State<_EdgePickerSheet> {
  List<ProductEdgeEntity>? _edges;
  ProductEdgeEntity? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEdges();
  }

  Future<void> _loadEdges() async {
    try {
      final ds = sl<ProductAttributesRemoteDataSource>();
      final edges = await ds.getProductEdges();
      if (!mounted) return;
      // Default selection: the edge with code 'R', or the first one.
      final defaultEdge = edges.firstWhere(
        (e) => e.code == 'R',
        orElse: () => edges.first,
      );
      setState(() {
        _edges = edges;
        _selected = defaultEdge;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'Qirra tanlang',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Standart: Tortburchak (R)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_edges == null || _edges!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Qirralar topilmadi.')),
            )
          else ...[
            ..._edges!.map((e) => _EdgeTile(
                  edge: e,
                  isSelected: _selected?.id == e.id,
                  onTap: () => setState(() => _selected = e),
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected != null
                    ? () => Navigator.of(context).pop(_selected)
                    : null,
                child: const Text('Tasdiqlash'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EdgeTile extends StatelessWidget {
  final ProductEdgeEntity edge;
  final bool isSelected;
  final VoidCallback onTap;

  const _EdgeTile({
    required this.edge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  edge.code,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                edge.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductPickerTile extends StatelessWidget {
  final ProductEntity product;

  const _ProductPickerTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final firstImageUrl = product.productColors
        .where((pc) => pc.imageUrl != null)
        .map((pc) => pc.imageUrl)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: firstImageUrl != null
                ? CachedNetworkImage(
                    imageUrl: firstImageUrl,
                    width: 44,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(4),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (product.productType != null)
                      _chip(product.productType!.type, AppColors.textSecondary),
                    if (product.productQuality != null)
                      _chip(product.productQuality!.qualityName, AppColors.primaryLight),
                    ...product.productColors.take(3).map(
                          (pc) => _chip(pc.colorName, AppColors.accent),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
      );
}
