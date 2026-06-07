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

/// Two-step picker: product (with inline edge dropdown) → colour.
///
/// Returns [ProductPickerResult] or null if the user dismisses any step.
class ProductPickerBottomSheet {
  ProductPickerBottomSheet._();

  static Future<ProductPickerResult?> show(BuildContext context) async {
    // Holds the edge selected via the dropdown in the title row.
    // Starts null — _EdgeSelector notifies us once it loads the default (R).
    ProductEdgeEntity? selectedEdge;

    // ── Step 1: search & pick product (edge dropdown in title row) ───────────
    final product = await showModalBottomSheet<ProductEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SearchPickerBottomSheet<ProductEntity>(
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
          titleTrailing: _EdgeSelector(
            onChanged: (edge) {
              selectedEdge = edge;
              // StatefulBuilder rebuild not needed — dropdown manages its own state.
            },
          ),
        ),
      ),
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

    return ProductPickerResult(product: product, color: color, edge: selectedEdge);
  }
}

// ── Edge selector dropdown (shown in title row of step 1) ────────────────────

class _EdgeSelector extends StatefulWidget {
  final void Function(ProductEdgeEntity edge) onChanged;

  const _EdgeSelector({required this.onChanged});

  @override
  State<_EdgeSelector> createState() => _EdgeSelectorState();
}

class _EdgeSelectorState extends State<_EdgeSelector> {
  List<ProductEdgeEntity> _edges = [];
  ProductEdgeEntity? _selected;

  @override
  void initState() {
    super.initState();
    _loadEdges();
  }

  Future<void> _loadEdges() async {
    try {
      final ds = sl<ProductAttributesRemoteDataSource>();
      final edges = await ds.getProductEdges();
      if (!mounted || edges.isEmpty) return;
      final defaultEdge = edges.firstWhere(
        (e) => e.code == 'R',
        orElse: () => edges.first,
      );
      setState(() {
        _edges = edges;
        _selected = defaultEdge;
      });
      widget.onChanged(defaultEdge);
    } catch (_) {
      // Silently ignore — edge stays null (backend will use its own default).
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_edges.isEmpty) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Container(
      width: 80,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ProductEdgeEntity>(
          value: _selected,
          isDense: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          icon: const Icon(Icons.expand_more_rounded, size: 16),
          borderRadius: BorderRadius.circular(10),
          items: _edges
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      e.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: (edge) {
            if (edge == null) return;
            setState(() => _selected = edge);
            widget.onChanged(edge);
          },
        ),
      ),
    );
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

// ── Product tile ──────────────────────────────────────────────────────────────

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
