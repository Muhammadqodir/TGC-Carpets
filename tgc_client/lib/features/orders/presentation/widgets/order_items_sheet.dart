import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_item_row.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/add_product.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/add_size.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/product_picker_cell.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/quantity_cell.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/size_picker_cell.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/size_summary_column.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';

class OrderItemsSheet extends StatefulWidget {
  const OrderItemsSheet({super.key, required this.ctrl});

  final OrderFormController ctrl;

  @override
  State<OrderItemsSheet> createState() => _OrderItemsSheetState();
}

class _OrderItemsSheetState extends State<OrderItemsSheet> {
  late LinkedScrollControllerGroup _controllers;
  late ScrollController _products;
  late ScrollController _quantities;
  final Map<String, FocusNode> _cellFocusNodes = {};
  String? _focusedRowKey;
  int? _focusedSizeId;

  // Track the last known row/column counts so we only rebuild on structure
  // changes, not on pure quantity-value changes.
  int _lastRowCount = 0;
  int _lastColCount = 0;

  void _onCtrlChanged() {
    final newRowCount = widget.ctrl.getUniqueItems().length;
    final newColCount = widget.ctrl.matrixSizeColumns.length;
    if (newRowCount != _lastRowCount || newColCount != _lastColCount) {
      _lastRowCount = newRowCount;
      _lastColCount = newColCount;
      setState(() {});
    }
  }

  // Called from QuantityCell via onFocusChanged.  Batches blur/focus pairs
  // so that arrow-key navigation (blur A → focus B) causes only ONE rebuild
  // instead of two: the blur defers its clear to a post-frame check that is
  // a no-op once B has already claimed focus.
  void _onCellFocusChanged(String rowKey, int sizeId, bool hasFocus) {
    if (hasFocus) {
      if (_focusedRowKey == rowKey && _focusedSizeId == sizeId) return;
      setState(() {
        _focusedRowKey = rowKey;
        _focusedSizeId = sizeId;
      });
    } else {
      // Defer the clear so an immediately following focus event on another cell
      // can cancel it (by having already updated _focusedRowKey/_focusedSizeId).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_focusedRowKey == rowKey && _focusedSizeId == sizeId) {
          setState(() {
            _focusedRowKey = null;
            _focusedSizeId = null;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrlChanged);
    _controllers = LinkedScrollControllerGroup();
    _products = _controllers.addAndGet();
    _quantities = _controllers.addAndGet();
  }

  FocusNode _getFocusNode(String rowKey, int sizeId) {
    final key = '${rowKey}_$sizeId';
    if (!_cellFocusNodes.containsKey(key)) {
      _cellFocusNodes[key] = FocusNode();
    }
    return _cellFocusNodes[key]!;
  }

  /// Groups [matrixSizeColumns] by productTypeId, preserving sort order.
  List<MapEntry<int, List<ProductSizeEntity>>> _sizeGroups() {
    final map = <int, List<ProductSizeEntity>>{};
    for (final size in widget.ctrl.matrixSizeColumns) {
      (map[size.productTypeId] ??= []).add(size);
    }
    return map.entries.toList();
  }

  /// Builds a typeId → typeName map from the currently added product rows.
  Map<int, String> _typeNameMap() {
    final map = <int, String>{};
    for (final row in widget.ctrl.getUniqueItems()) {
      final typeId =
          row.selectedProduct?.productTypeId ?? row.prefilledProductTypeId;
      final typeName =
          row.selectedProduct?.productType?.type ?? row.prefilledProductTypeName;
      if (typeId != null && typeName != null) map[typeId] = typeName;
    }
    return map;
  }

  String _rowKey(OrderItemRow row) {
    final colorId = row.selectedColor?.id ?? row.prefilledColorId;
    final edgeId = row.effectiveEdgeId;
    return '${colorId}_e${edgeId ?? 0}';
  }

  void _navigateToCell(int rowIndex, int columnIndex) {
    final rows = widget.ctrl.getUniqueItems();
    final cols = widget.ctrl.matrixSizeColumns;
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    if (columnIndex < 0 || columnIndex >= cols.length) return;
    final sizeId = cols[columnIndex].id;
    _getFocusNode(_rowKey(rows[rowIndex]), sizeId).requestFocus();
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_onCtrlChanged);
    _products.dispose();
    _quantities.dispose();
    for (final node in _cellFocusNodes.values) {
      node.dispose();
    }
    _cellFocusNodes.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(12),
      // decoration: BoxDecoration(
      //   color: AppColors.background,
      //   border: Border.all(color: AppColors.divider),
      // ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Column(
              children: [
                // Matches the two-row size header (24px label + 40px cell).
                const SizedBox(height: 64),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    controller: _products,
                    child: Column(
                      children: [
                        ...widget.ctrl.getUniqueItems().map((row) {
                          final rk = _rowKey(row);
                          return ProductPickerCell(
                            key: ValueKey('product_$rk'),
                            row: row,
                            ctrl: widget.ctrl,
                            isHighlighted: _focusedRowKey == rk,
                            onDelete: () => widget.ctrl.removeMatrixRow(row),
                          );
                        }),
                        AddProduct(ctrl: widget.ctrl),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 80,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sizes header: type-label row + size-picker row.
                  Builder(builder: (context) {
                    final groups = _sizeGroups();
                    final typeNames = _typeNameMap();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Type label row (24 px) ──────────────────────────
                        Row(
                          children: [
                            ...groups.map((entry) {
                              final name = typeNames[entry.key] ??
                                  'Tur #${entry.key}';
                              return Container(
                                width: 120.0 * entry.value.length,
                                height: 24,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.08),
                                  border: Border(
                                    bottom: BorderSide(
                                        color: AppColors.divider),
                                    right: BorderSide(
                                        color: AppColors.divider),
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                            // Spacer aligned with AddSize button
                            const SizedBox(width: 120, height: 24),
                          ],
                        ),
                        // ── Size picker cells row (40 px) ───────────────────
                        Row(
                          children: [
                            ...widget.ctrl.matrixSizeColumns.map(
                              (size) => SizePickerCell(
                                key: ValueKey('size_header_${size.id}'),
                                size: size,
                                isHighlighted: _focusedSizeId == size.id,
                                onRemove: () =>
                                    widget.ctrl
                                        .removeMatrixSizeColumn(size.id),
                                onReplace: (newSize) => widget.ctrl
                                    .replaceMatrixSizeColumn(
                                        size.id, newSize),
                              ),
                            ),
                            AddSize(
                              onSizeAdded: widget.ctrl.addMatrixSizeColumn,
                              alreadySelectedSizeIds: widget
                                  .ctrl.matrixSizeColumns
                                  .map((s) => s.id)
                                  .toSet(),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      controller: _quantities,
                      child: Column(
                        children: [
                          // Quantity cells — one row per unique product+colour, aligned
                          // with the left column (both iterate getUniqueItems()).
                          ...widget.ctrl.getUniqueItems().asMap().entries.map(
                            (entry) {
                              final rowIndex = entry.key;
                              final row = entry.value;
                              final colorId =
                                  row.selectedColor?.id ?? row.prefilledColorId;
                              final rk = _rowKey(row);
                              final rowTypeId =
                                  row.selectedProduct?.productTypeId ??
                                      row.prefilledProductTypeId;
                              if (colorId == null)
                                return const SizedBox(
                                    key: ValueKey('empty_row'), height: 40);
                              return SizedBox(
                                key: ValueKey('quantity_row_$rk'),
                                height: 40,
                                child: Row(
                                  children: [
                                    ...widget.ctrl.matrixSizeColumns
                                        .asMap()
                                        .entries
                                        .map(
                                      (colEntry) {
                                        final columnIndex = colEntry.key;
                                        final size = colEntry.value;
                                        final enabled = rowTypeId != null &&
                                            rowTypeId == size.productTypeId;
                                        return QuantityCell(
                                          key: ValueKey('cell_${rk}_${size.id}'),
                                          ctrl: widget.ctrl,
                                          colorId: colorId,
                                          sizeId: size.id,
                                          edgeId: row.effectiveEdgeId,
                                          enabled: enabled,
                                          rowIndex: rowIndex,
                                          columnIndex: columnIndex,
                                          totalRows: widget.ctrl.getUniqueItems().length,
                                          totalColumns: widget.ctrl.matrixSizeColumns.length,
                                          onNavigate: _navigateToCell,
                                          focusNode: _getFocusNode(rk, size.id),
                                          onFocusChanged: (hasFocus) =>
                                              _onCellFocusChanged(rk, size.id, hasFocus),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          SizedBox(
                            height: 40,
                          )
                        ],
                      ),
                    ),
                  ),

                  // ── Summary row (Uzunlik + Maydon per size column) ───────
                  Row(
                    children: widget.ctrl.matrixSizeColumns
                        .map((size) => SizeSummaryColumn(
                              key: ValueKey('summary_${size.id}'),
                              ctrl: widget.ctrl,
                              size: size,
                              isHighlighted: _focusedSizeId == size.id,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
