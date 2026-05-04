import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/add_product.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/add_size.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/product_picker_cell.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/quantity_cell.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/size_picker_cell.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/size_summary_column.dart';

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

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onCtrlChanged);
    _controllers = LinkedScrollControllerGroup();
    _products = _controllers.addAndGet();
    _quantities = _controllers.addAndGet();
  }

  void _onCtrlChanged() => setState(() {});

  FocusNode _getFocusNode(int rowIndex, int columnIndex) {
    final key = '${rowIndex}_$columnIndex';
    if (!_cellFocusNodes.containsKey(key)) {
      _cellFocusNodes[key] = FocusNode();
    }
    return _cellFocusNodes[key]!;
  }

  void _navigateToCell(int rowIndex, int columnIndex) {
    final focusNode = _getFocusNode(rowIndex, columnIndex);
    focusNode.requestFocus();
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
                SizedBox(
                  height: 40,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    controller: _products,
                    child: Column(
                      children: [
                        ...widget.ctrl.getUniqueItems().map((row) {
                          final colorId =
                              row.selectedColor?.id ?? row.prefilledColorId;
                          return ProductPickerCell(
                            key: ValueKey('product_$colorId'),
                            row: row,
                            ctrl: widget.ctrl,
                            onDelete: () {
                              if (colorId != null) {
                                widget.ctrl.removeMatrixColorRow(colorId);
                              }
                            },
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
                  //Sizes list
                  Row(
                    children: [
                      ...widget.ctrl.matrixSizeColumns.map(
                        (size) => SizePickerCell(
                          key: ValueKey('size_header_${size.id}'),
                          size: size,
                          onRemove: () =>
                              widget.ctrl.removeMatrixSizeColumn(size.id),
                          onReplace: (newSize) => widget.ctrl
                              .replaceMatrixSizeColumn(size.id, newSize),
                        ),
                      ),
                      AddSize(
                        onSizeAdded: widget.ctrl.addMatrixSizeColumn,
                        alreadySelectedSizeIds: widget.ctrl.matrixSizeColumns
                            .map((s) => s.id)
                            .toSet(),
                      ),
                    ],
                  ),
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
                              final rowTypeId =
                                  row.selectedProduct?.productTypeId ??
                                      row.prefilledProductTypeId;
                              if (colorId == null)
                                return const SizedBox(
                                    key: ValueKey('empty_row'), height: 40);
                              return SizedBox(
                                key: ValueKey('quantity_row_$colorId'),
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
                                          key: ValueKey('cell_${colorId}_${size.id}'),
                                          ctrl: widget.ctrl,
                                          colorId: colorId,
                                          sizeId: size.id,
                                          enabled: enabled,
                                          rowIndex: rowIndex,
                                          columnIndex: columnIndex,
                                          totalRows: widget.ctrl.getUniqueItems().length,
                                          totalColumns: widget.ctrl.matrixSizeColumns.length,
                                          onNavigate: _navigateToCell,
                                          focusNode: _getFocusNode(rowIndex, columnIndex),
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
