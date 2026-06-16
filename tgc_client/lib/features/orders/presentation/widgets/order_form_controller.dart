import 'package:flutter/material.dart';
import 'package:tgc_client/features/products/domain/entities/product_color_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_edge_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';

import 'order_item_row.dart';

/// Shared form state for the "add order" flow.
///
/// Lives in [AddOrderPage] and is passed down to both the mobile and desktop
/// layout variants so state survives adaptive layout switches on resize.
///
/// Follows the same pattern as [WarehouseDocumentFormController]:
/// always keeps an empty sentinel row at the end — filling it in
/// auto-appends the next empty row via [_ensureEmptyRowAtEnd].
class OrderFormController extends ChangeNotifier {
  final List<OrderItemRow> items = [];
  final TextEditingController notesCtrl = TextEditingController();

  /// [initialRows] allows pre-populating the list (edit mode).
  OrderFormController({List<OrderItemRow> initialRows = const []}) {
    notesCtrl.addListener(notifyListeners);
    for (final row in initialRows) {
      row.quantityCtrl.addListener(notifyListeners);
      items.add(row);
    }
    _ensureEmptyRowAtEnd();
  }

  // ── Item mutations ────────────────────────────────────────────────────────

  void _addItem() {
    final row = OrderItemRow();
    row.quantityCtrl.addListener(notifyListeners);
    items.add(row);
  }

  void addSizeRow(ProductSizeEntity size) {
    final row = OrderItemRow(
      prefilledSizeId: size.id,
      prefilledSizeLength: size.length,
      prefilledSizeWidth: size.width,
    );
    row.quantityCtrl.addListener(notifyListeners);
    items.add(row);
  }

  void removeItem(int index) {
    final row = items[index];
    row.quantityCtrl.removeListener(notifyListeners);
    row.dispose();
    items.removeAt(index);
    _ensureEmptyRowAtEnd();
    notifyListeners();
  }

  /// Call after directly mutating a row's product / color / size fields.
  void notifyChanged() {
    _ensureEmptyRowAtEnd();
    notifyListeners();
  }

  /// Always keeps exactly one empty sentinel row at the end.
  void _ensureEmptyRowAtEnd() {
    // Trim extra trailing empty rows
    while (items.length > 1 && _isRowEmpty(items.last)) {
      final last = items.removeLast();
      last.quantityCtrl.removeListener(notifyListeners);
      last.dispose();
    }
    // Append a new empty row if we have none or the last row is filled
    if (items.isEmpty || !_isRowEmpty(items.last)) {
      _addItem();
    }
  }

  /// A row is "empty" (sentinel) when it has neither entity data nor prefilled IDs.
  bool _isRowEmpty(OrderItemRow row) =>
      row.selectedProduct == null && row.prefilledColorId == null;

  /// Rows that have a product selected (excludes the sentinel empty row).
  List<OrderItemRow> get filledItems =>
      items.where((r) => !_isRowEmpty(r)).toList();

  /// True when the sheet is in matrix mode (at least one size column added).
  bool get isMatrixMode => matrixSizeColumns.isNotEmpty;

  /// Submission payload for the matrix sheet.
  ///
  /// Iterates every filled product+colour row in [items] against every size
  /// column and collects cells where quantity > 0.  The result is ready to
  /// pass directly to [OrderFormSubmitted.items].
  /// Total quantity across all product rows for a given size column.
  int totalQtyForSize(int sizeId) {
    var total = 0;
    for (final row in getUniqueItems()) {
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      total += _matrixQty[_matrixKey(colorId, sizeId, edgeId: row.effectiveEdgeId)] ?? 0;
    }
    return total;
  }

  List<Map<String, dynamic>> get sheetMatrixFilledItems {
    final result = <Map<String, dynamic>>[];
    for (final row in getUniqueItems()) {
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      final edgeId = row.effectiveEdgeId;
      for (final size in matrixSizeColumns) {
        final qty = _matrixQty[_matrixKey(colorId, size.id, edgeId: edgeId)] ?? 0;
        if (qty > 0) {
          result.add({
            'product_color_id': colorId,
            'product_size_id': size.id,
            'quantity': qty,
            if (edgeId != null) 'product_edge_id': edgeId,
          });
        }
      }
    }
    return result;
  }

  @override
  void dispose() {
    for (final row in items) {
      row.quantityCtrl.removeListener(notifyListeners);
      row.dispose();
    }
    notesCtrl.removeListener(notifyListeners);
    notesCtrl.dispose();
    for (final c in _matrixCellCtrls.values) {
      c.dispose();
    }
    _matrixCellCtrls.clear();
    _matrixQty.clear();
    super.dispose();
  }

  /// Returns one representative [OrderItemRow] per unique (product, color, edge)
  /// combination, skipping empty/sentinel rows.
  List<OrderItemRow> getUniqueItems() {
    final seen = <String>{};
    final result = <OrderItemRow>[];
    for (final item in items) {
      if (_isRowEmpty(item)) continue;
      final colorId = item.selectedColor?.id ?? item.prefilledColorId;
      final productId = item.selectedProduct?.id;
      final edgeId = item.effectiveEdgeId;
      if (seen.add('${productId}_${colorId}_$edgeId')) result.add(item);
    }
    return result;
  }

  // ── Matrix mode ─────────────────────────────────────────────────────────────

  final List<ProductSizeEntity> matrixSizeColumns = [];
  final Map<String, TextEditingController> _matrixCellCtrls = {};

  /// Stores the latest parsed integer quantity for each cell key.
  /// Updated eagerly on every keystroke; read at submit time.
  final Map<String, int> _matrixQty = {};

  String _matrixKey(int colorId, int sizeId, {int? edgeId}) =>
      '${colorId}_e${edgeId ?? 0}_$sizeId';

  /// Returns (or lazily creates) the quantity [TextEditingController] for
  /// the cell at (colorId × edgeId × sizeId) in the matrix.
  TextEditingController matrixCellCtrl(int colorId, int sizeId, {int? edgeId}) {
    final key = _matrixKey(colorId, sizeId, edgeId: edgeId);
    return _matrixCellCtrls.putIfAbsent(key, () {
      final c = TextEditingController();
      c.addListener(() {
        _matrixQty[key] = int.tryParse(c.text.trim()) ?? 0;
        // Notify listeners so the form page knows to save the draft
        notifyListeners();
      });
      return c;
    });
  }

  /// Seeds [matrixSizeColumns] and pre-fills [_matrixQty] / cell controllers
  /// from the existing [items] rows that carry prefill data (edit mode).
  ///
  /// Must be called **after** the super-constructor has populated [items].
  void seedMatrixFromPrefill() {
    for (final row in items) {
      final sizeId = row.prefilledSizeId;
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (sizeId == null || colorId == null) continue;
      if (row.prefilledSizeLength == null || row.prefilledSizeWidth == null) continue;
      final productTypeId = row.selectedProduct?.productTypeId ?? row.prefilledProductTypeId;
      if (productTypeId == null) continue;

      // Add the size column if not already present.
      if (!matrixSizeColumns.any((s) => s.id == sizeId)) {
        matrixSizeColumns.add(ProductSizeEntity(
          id: sizeId,
          length: row.prefilledSizeLength!,
          width: row.prefilledSizeWidth!,
          productTypeId: productTypeId,
        ));
      }

      // Pre-fill the quantity cell.
      final qty = int.tryParse(row.quantityCtrl.text.trim()) ?? 0;
      if (qty > 0) {
        final edgeId = row.effectiveEdgeId;
        final key = _matrixKey(colorId, sizeId, edgeId: edgeId);
        final ctrl = matrixCellCtrl(colorId, sizeId, edgeId: edgeId);
        ctrl.text = '$qty';
        _matrixQty[key] = qty;
      }
    }
    _sortMatrixSizeColumns();
  }

  /// Adds a new product+color+edge row to the matrix.
  /// Returns false if the (color, edge) combination is already present.
  bool addMatrixColorRow(
    ProductEntity product,
    ProductColorEntity color, [
    ProductEdgeEntity? edge,
  ]) {
    final edgeId = edge?.id;
    final alreadyExists = getUniqueItems().any((r) {
      final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
      return rColorId == color.id && r.effectiveEdgeId == edgeId;
    });
    if (alreadyExists) return false;
    final row = OrderItemRow()
      ..selectedProduct = product
      ..selectedColor = color
      ..selectedEdge = edge;
    row.quantityCtrl.addListener(notifyListeners);
    items.add(row);
    for (final s in matrixSizeColumns) {
      matrixCellCtrl(color.id, s.id, edgeId: edgeId);
    }
    notifyListeners();
    return true;
  }

  /// Removes the specific [row] from the matrix and disposes its cell data.
  void removeMatrixRow(OrderItemRow row) {
    final colorId = row.selectedColor?.id ?? row.prefilledColorId;
    final edgeId = row.effectiveEdgeId;
    row.quantityCtrl.removeListener(notifyListeners);
    row.dispose();
    items.remove(row);
    if (colorId != null) {
      for (final s in matrixSizeColumns) {
        _disposeMatrixCell(_matrixKey(colorId, s.id, edgeId: edgeId));
      }
    }
    notifyListeners();
  }

  /// Updates the product+color+edge for the row identified by [oldColorId] and
  /// [oldEdgeId]. Migrates cell quantities when the identity changes.
  /// Returns false if the new (color, edge) combination is already in use.
  bool updateMatrixProductRow(
    int oldColorId,
    ProductEntity newProduct,
    ProductColorEntity newColor, [
    ProductEdgeEntity? edge,
    int? oldEdgeId,
  ]) {
    final newEdgeId = edge?.id;
    final identityChanged = newColor.id != oldColorId || newEdgeId != oldEdgeId;
    if (identityChanged) {
      final alreadyExists = getUniqueItems().any((r) {
        final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
        return rColorId == newColor.id && r.effectiveEdgeId == newEdgeId;
      });
      if (alreadyExists) return false;
    }
    for (final r in items) {
      if ((r.selectedColor?.id ?? r.prefilledColorId) == oldColorId &&
          r.effectiveEdgeId == oldEdgeId) {
        r.selectedProduct = newProduct;
        r.selectedColor = newColor;
        r.selectedEdge = edge;
      }
    }
    if (identityChanged) {
      for (final s in matrixSizeColumns) {
        final oldKey = _matrixKey(oldColorId, s.id, edgeId: oldEdgeId);
        final qty = _matrixQty[oldKey] ?? 0;
        _disposeMatrixCell(oldKey);
        if (qty > 0) {
          final ctrl = matrixCellCtrl(newColor.id, s.id, edgeId: newEdgeId);
          ctrl.text = '$qty';
          _matrixQty[_matrixKey(newColor.id, s.id, edgeId: newEdgeId)] = qty;
        }
      }
    }
    notifyListeners();
    return true;
  }

  void _sortMatrixSizeColumns() {
    matrixSizeColumns.sort((a, b) {
      final typeCmp = a.productTypeId.compareTo(b.productTypeId);
      if (typeCmp != 0) return typeCmp;
      final widthCmp = a.width.compareTo(b.width);
      return widthCmp != 0 ? widthCmp : a.length.compareTo(b.length);
    });
  }

  /// Adds a size column. Returns false if the size is already a column.
  bool addMatrixSizeColumn(ProductSizeEntity size) {
    if (matrixSizeColumns.any((s) => s.id == size.id)) return false;
    matrixSizeColumns.add(size);
    _sortMatrixSizeColumns();
    for (final row in getUniqueItems()) {
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      matrixCellCtrl(colorId, size.id, edgeId: row.effectiveEdgeId);
    }
    notifyListeners();
    return true;
  }

  /// Replaces a size column, migrating existing cell quantities to the new size.
  void replaceMatrixSizeColumn(int oldSizeId, ProductSizeEntity newSize) {
    if (newSize.id == oldSizeId) return;
    if (matrixSizeColumns.any((s) => s.id == newSize.id)) return;
    final idx = matrixSizeColumns.indexWhere((s) => s.id == oldSizeId);
    if (idx == -1) return;
    matrixSizeColumns[idx] = newSize;
    _sortMatrixSizeColumns();
    for (final row in getUniqueItems()) {
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      final edgeId = row.effectiveEdgeId;
      final oldKey = _matrixKey(colorId, oldSizeId, edgeId: edgeId);
      final qty = _matrixQty[oldKey] ?? 0;
      _disposeMatrixCell(oldKey);
      if (qty > 0) {
        final ctrl = matrixCellCtrl(colorId, newSize.id, edgeId: edgeId);
        ctrl.text = '$qty';
        _matrixQty[_matrixKey(colorId, newSize.id, edgeId: edgeId)] = qty;
      }
    }
    notifyListeners();
  }

  /// Removes a size column and disposes its cell controllers.
  void removeMatrixSizeColumn(int sizeId) {
    matrixSizeColumns.removeWhere((s) => s.id == sizeId);
    for (final row in getUniqueItems()) {
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      _disposeMatrixCell(_matrixKey(colorId, sizeId, edgeId: row.effectiveEdgeId));
    }
    notifyListeners();
  }

  void _disposeMatrixCell(String key) {
    _matrixCellCtrls[key]?.dispose();
    _matrixCellCtrls.remove(key);
    _matrixQty.remove(key);
  }

  // ── Form clear ────────────────────────────────────────────────────────────

  /// Resets the form to its initial blank state: clears all items, notes, and
  /// matrix data, then re-adds the empty sentinel row.
  void clearForm() {
    // Dispose & clear items
    for (final row in items) {
      row.quantityCtrl.removeListener(notifyListeners);
      row.dispose();
    }
    items.clear();

    // Clear notes
    notesCtrl.removeListener(notifyListeners);
    notesCtrl.clear();
    notesCtrl.addListener(notifyListeners);

    // Clear matrix data
    for (final c in _matrixCellCtrls.values) {
      c.dispose();
    }
    _matrixCellCtrls.clear();
    _matrixQty.clear();
    matrixSizeColumns.clear();

    _ensureEmptyRowAtEnd();
    notifyListeners();
  }

  // ── Draft restoration ──────────────────────────────────────────────────────

  /// Restores the form state from a draft. Clears current items and replaces
  /// them with the draft data without triggering listeners until complete.
  /// Safe to call from an async context before the widget is shown.
  void restoreFrom({
    required List<OrderItemRow> newItems,
    required String notes,
    List<ProductSizeEntity>? matrixSizes,
    Map<String, int>? matrixQty,
  }) {
    // Clear existing items
    for (final row in items) {
      row.quantityCtrl.removeListener(notifyListeners);
      row.dispose();
    }
    items.clear();

    // Update notes
    notesCtrl.removeListener(notifyListeners);
    notesCtrl.text = notes;
    notesCtrl.addListener(notifyListeners);

    // Add new items
    for (final row in newItems) {
      row.quantityCtrl.addListener(notifyListeners);
      items.add(row);
    }

    // Restore matrix mode if applicable
    if (matrixSizes != null && matrixSizes.isNotEmpty) {
      matrixSizeColumns.clear();
      matrixSizeColumns.addAll(matrixSizes);
      _sortMatrixSizeColumns();

      // Clear existing matrix data
      for (final c in _matrixCellCtrls.values) {
        c.dispose();
      }
      _matrixCellCtrls.clear();
      _matrixQty.clear();

      // Restore matrix quantities.
      // Key format: '${colorId}_e${edgeId ?? 0}_${sizeId}'
      if (matrixQty != null) {
        for (final entry in matrixQty.entries) {
          _matrixQty[entry.key] = entry.value;
          final parts = entry.key.split('_');
          if (parts.length == 3) {
            final colorId = int.tryParse(parts[0]);
            // parts[1] is 'e{edgeId}' — strip the leading 'e'
            final edgeRaw = int.tryParse(
              parts[1].startsWith('e') ? parts[1].substring(1) : parts[1],
            );
            final edgeId = (edgeRaw != null && edgeRaw > 0) ? edgeRaw : null;
            final sizeId = int.tryParse(parts[2]);
            if (colorId != null && sizeId != null) {
              final ctrl = matrixCellCtrl(colorId, sizeId, edgeId: edgeId);
              ctrl.text = '${entry.value}';
            }
          }
        }
      }
    } else {
      // No explicit matrix snapshot — seed from prefill data on the rows.
      // This handles the copy-order flow where rows carry prefilledSizeId /
      // prefilledSizeLength / prefilledSizeWidth / initialQuantity but no
      // separate matrix_size_columns blob was saved.
      seedMatrixFromPrefill();
    }

    _ensureEmptyRowAtEnd();
    // Force a rebuild by notifying listeners AFTER everything is set up
    notifyListeners();
  }

}

