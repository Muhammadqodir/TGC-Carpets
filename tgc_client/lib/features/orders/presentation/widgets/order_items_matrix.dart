import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/presentation/widgets/product_picker_bottom_sheet.dart';
import '../../../products/presentation/widgets/product_size_picker_sheet.dart';
import 'order_form_controller.dart';

// ── Layout constants ──────────────────────────────────────────────────────────
const double _kProductColWidth = 200.0;
const double _kSizeColWidth = 90.0;
const double _kRowHeight = 48.0;
const double _kHeaderHeight = 36.0;

/// Matrix-style order item form.
///
/// Layout:
/// ```
/// ┌──────────────────────┬────────┬────────┬──────────┐
/// │ Mahsulot / Rang      │ 150×80 │ 200×80 │ +O'lcham │
/// ├──────────────────────┼────────┼────────┼──────────┤
/// │ [img] Carpet A / Red │ [ 5 ]  │ [ 3 ]  │          │
/// ├──────────────────────┼────────┼────────┼──────────┤
/// │ + Mahsulot qo'shish  │        │        │          │
/// └──────────────────────┴────────┴────────┴──────────┘
/// ```
/// Rows  = unique product+colour combos (left sticky column).
/// Columns = sizes (horizontally scrollable).
/// Cells = quantity inputs.
///
/// Uses [OrderFormController.matrixProductRows], [OrderFormController.matrixSizeColumns],
/// and [OrderFormController.matrixCellCtrl] for state; calls
/// [OrderFormController.matrixFilledItems] to collect submission data.
class OrderItemsMatrix extends StatelessWidget {
  const OrderItemsMatrix({super.key, required this.ctrl});

  final OrderFormController ctrl;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final productRows = ctrl.matrixProductRows;
        final sizeColumns = ctrl.matrixSizeColumns;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sticky left column ──────────────────────────────────────────
            SizedBox(
              width: _kProductColWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ColumnHeader('Mahsulot / Rang'),
                  ...productRows.map(
                    (row) => SizedBox(
                      height: _kRowHeight,
                      child: _ProductLabelCell(
                        row: row,
                        onRemove: () =>
                            ctrl.removeMatrixProductRow(row.color.id),
                      ),
                    ),
                  ),
                  _AddProductButton(
                    onAdded: (p, c) => _handleProductAdded(context, p, c),
                  ),
                ],
              ),
            ),

            // ── Scrollable right section ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with size labels + add-size button
                    Row(
                      children: [
                        ...sizeColumns.map(
                          (size) => _SizeHeaderCell(
                            size: size,
                            onRemove: () =>
                                ctrl.removeMatrixSizeColumn(size.id),
                          ),
                        ),
                        _AddSizeButton(
                          onAdded: (s) => _handleSizeAdded(context, s),
                        ),
                      ],
                    ),

                    // Data rows — one per product+colour
                    ...productRows.map(
                      (row) => SizedBox(
                        height: _kRowHeight,
                        child: Row(
                          children: [
                            ...sizeColumns.map(
                              (size) => _QuantityCell(
                                controller:
                                    ctrl.matrixCellCtrl(row.color.id, size.id),
                              ),
                            ),
                            // Spacer beneath the add-size header button
                            const SizedBox(width: _kSizeColWidth),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleProductAdded(
    BuildContext context,
    ProductEntity product,
    ProductColorEntity color,
  ) {
    final added = ctrl.addMatrixProductRow(product, color);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu mahsulot varianti allaqachon qo'shilgan."),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleSizeAdded(BuildContext context, ProductSizeEntity size) {
    final added = ctrl.addMatrixSizeColumn(size);
    if (!added && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bu o'lcham allaqachon qo'shilgan."),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Column header (top-left label cell)
// ─────────────────────────────────────────────────────────────────────────────

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kHeaderHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product label cell (sticky left column, one per row)
// ─────────────────────────────────────────────────────────────────────────────

class _ProductLabelCell extends StatelessWidget {
  const _ProductLabelCell({required this.row, required this.onRemove});

  final MatrixProductRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          AppThumbnail(
            imageUrl: row.color.imageUrl,
            size: 28,
            borderRadius: 4,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  row.color.colorName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Size header cell (top of each size column, tappable × to remove)
// ─────────────────────────────────────────────────────────────────────────────

class _SizeHeaderCell extends StatelessWidget {
  const _SizeHeaderCell({required this.size, required this.onRemove});

  final ProductSizeEntity size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSizeColWidth,
      height: _kHeaderHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            size.dimensions,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quantity input cell (intersection of product row × size column)
// ─────────────────────────────────────────────────────────────────────────────

class _QuantityCell extends StatelessWidget {
  const _QuantityCell({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSizeColWidth,
      height: _kRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider),
          right: BorderSide(color: AppColors.divider),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(5)),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          hintText: '—',
          hintStyle: const TextStyle(
            color: AppColors.divider,
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add product row button (bottom of the left column)
// ─────────────────────────────────────────────────────────────────────────────

class _AddProductButton extends StatelessWidget {
  const _AddProductButton({required this.onAdded});

  final void Function(ProductEntity, ProductColorEntity) onAdded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kRowHeight,
      child: TextButton.icon(
        onPressed: () async {
          final result = await ProductPickerBottomSheet.show(context);
          if (result != null && result.color != null && context.mounted) {
            onAdded(result.product, result.color!);
          }
        },
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text(
          "Mahsulot qo'shish",
          style: TextStyle(fontSize: 12),
        ),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add size column button (rightmost header cell)
// ─────────────────────────────────────────────────────────────────────────────

class _AddSizeButton extends StatelessWidget {
  const _AddSizeButton({required this.onAdded});

  final void Function(ProductSizeEntity) onAdded;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await ProductSizePickerSheet.show(context);
        if (picked != null && context.mounted) {
          onAdded(picked);
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: _kSizeColWidth,
        height: _kHeaderHeight,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          border: Border(
            bottom: BorderSide(color: AppColors.divider),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
            SizedBox(width: 3),
            Text(
              "O'lcham",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
