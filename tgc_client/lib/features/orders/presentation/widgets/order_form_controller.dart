import 'package:flutter/material.dart';
import 'package:tgc_client/features/products/domain/entities/product_color_entity.dart';
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
    for (final colorId in _uniqueColorIds) {
      total += _matrixQty[_matrixKey(colorId, sizeId)] ?? 0;
    }
    return total;
  }

  List<Map<String, dynamic>> get sheetMatrixFilledItems {
    final seen = <int>{};
    final result = <Map<String, dynamic>>[];
    for (final row in items) {
      if (_isRowEmpty(row)) continue;
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      if (!seen.add(colorId)) continue; // skip duplicate color rows (edit mode)
      for (final size in matrixSizeColumns) {
        final qty = _matrixQty[_matrixKey(colorId, size.id)] ?? 0;
        if (qty > 0) {
          result.add({
            'product_color_id': colorId,
            'product_size_id': size.id,
            'quantity': qty,
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

  /// Returns one representative [OrderItemRow] per unique (product, color)
  /// combination, skipping empty/sentinel rows.
  List<OrderItemRow> getUniqueItems() {
    final seen = <String>{};
    final result = <OrderItemRow>[];
    for (final item in items) {
      if (_isRowEmpty(item)) continue;
      final colorId = item.selectedColor?.id ?? item.prefilledColorId;
      final productId = item.selectedProduct?.id;
      if (seen.add('${productId}_$colorId')) result.add(item);
    }
    return result;
  }

  // ── Matrix mode ─────────────────────────────────────────────────────────────

  final List<ProductSizeEntity> matrixSizeColumns = [];
  final Map<String, TextEditingController> _matrixCellCtrls = {};

  /// Stores the latest parsed integer quantity for each cell key.
  /// Updated eagerly on every keystroke; read at submit time.
  final Map<String, int> _matrixQty = {};

  String _matrixKey(int colorId, int sizeId) => '${colorId}_$sizeId';

  /// Returns (or lazily creates) the quantity [TextEditingController] for
  /// the cell at (colorId × sizeId) in the matrix.
  TextEditingController matrixCellCtrl(int colorId, int sizeId) {
    final key = _matrixKey(colorId, sizeId);
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
        final key = _matrixKey(colorId, sizeId);
        final ctrl = matrixCellCtrl(colorId, sizeId);
        ctrl.text = '$qty';
        _matrixQty[key] = qty;
      }
    }
  }

  /// Color IDs of all currently filled unique product rows.
  List<int> get _uniqueColorIds => getUniqueItems()
      .map((r) => r.selectedColor?.id ?? r.prefilledColorId)
      .whereType<int>()
      .toList();

  /// Adds a new product+color row to the matrix. Returns false if the color is
  /// already present.
  bool addMatrixColorRow(ProductEntity product, ProductColorEntity color) {
    if (_uniqueColorIds.contains(color.id)) return false;
    final row = OrderItemRow()
      ..selectedProduct = product
      ..selectedColor = color;
    row.quantityCtrl.addListener(notifyListeners);
    items.add(row);
    for (final s in matrixSizeColumns) {
      matrixCellCtrl(color.id, s.id);
    }
    notifyListeners();
    return true;
  }

  /// Removes all rows for [colorId] and clears their cell data.
  void removeMatrixColorRow(int colorId) {
    final toRemove = items
        .where((r) => (r.selectedColor?.id ?? r.prefilledColorId) == colorId)
        .toList();
    for (final r in toRemove) {
      r.quantityCtrl.removeListener(notifyListeners);
      r.dispose();
      items.remove(r);
    }
    for (final s in matrixSizeColumns) {
      _disposeMatrixCell(_matrixKey(colorId, s.id));
    }
    notifyListeners();
  }

  /// Updates the product+color for all rows identified by [oldColorId].
  /// Migrates cell quantities when the color changes.
  /// Returns false if [newColor] is already in use by another row.
  bool updateMatrixProductRow(
    int oldColorId,
    ProductEntity newProduct,
    ProductColorEntity newColor,
  ) {
    if (newColor.id != oldColorId && _uniqueColorIds.contains(newColor.id)) {
      return false;
    }
    for (final r in items) {
      if ((r.selectedColor?.id ?? r.prefilledColorId) == oldColorId) {
        r.selectedProduct = newProduct;
        r.selectedColor = newColor;
      }
    }
    if (newColor.id != oldColorId) {
      for (final s in matrixSizeColumns) {
        final oldKey = _matrixKey(oldColorId, s.id);
        final qty = _matrixQty[oldKey] ?? 0;
        _disposeMatrixCell(oldKey);
        if (qty > 0) {
          final ctrl = matrixCellCtrl(newColor.id, s.id);
          ctrl.text = '$qty';
          _matrixQty[_matrixKey(newColor.id, s.id)] = qty;
        }
      }
    }
    notifyListeners();
    return true;
  }

  /// Adds a size column. Returns false if the size is already a column.
  bool addMatrixSizeColumn(ProductSizeEntity size) {
    if (matrixSizeColumns.any((s) => s.id == size.id)) return false;
    matrixSizeColumns.add(size);
    for (final colorId in _uniqueColorIds) {
      matrixCellCtrl(colorId, size.id);
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
    for (final colorId in _uniqueColorIds) {
      final oldKey = _matrixKey(colorId, oldSizeId);
      final qty = _matrixQty[oldKey] ?? 0;
      _disposeMatrixCell(oldKey);
      if (qty > 0) {
        final ctrl = matrixCellCtrl(colorId, newSize.id);
        ctrl.text = '$qty';
        _matrixQty[_matrixKey(colorId, newSize.id)] = qty;
      }
    }
    notifyListeners();
  }

  /// Removes a size column and disposes its cell controllers.
  void removeMatrixSizeColumn(int sizeId) {
    matrixSizeColumns.removeWhere((s) => s.id == sizeId);
    for (final colorId in _uniqueColorIds) {
      _disposeMatrixCell(_matrixKey(colorId, sizeId));
    }
    notifyListeners();
  }

  void _disposeMatrixCell(String key) {
    _matrixCellCtrls[key]?.dispose();
    _matrixCellCtrls.remove(key);
    _matrixQty.remove(key);
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
    print('DEBUG: restoreFrom - adding ${newItems.length} items');
    for (final row in newItems) {
      print('DEBUG: Adding row with quantity: ${row.quantityCtrl.text}');
      row.quantityCtrl.addListener(notifyListeners);
      items.add(row);
    }
    print('DEBUG: After adding items, items.length = ${items.length}');
    for (int i = 0; i < items.length; i++) {
      print('DEBUG: Item $i quantity: ${items[i].quantityCtrl.text}');
    }

    // Restore matrix mode if applicable
    if (matrixSizes != null && matrixSizes.isNotEmpty) {
      matrixSizeColumns.clear();
      matrixSizeColumns.addAll(matrixSizes);

      // Clear existing matrix data
      for (final c in _matrixCellCtrls.values) {
        c.dispose();
      }
      _matrixCellCtrls.clear();
      _matrixQty.clear();

      // Restore matrix quantities
      if (matrixQty != null) {
        for (final entry in matrixQty.entries) {
          _matrixQty[entry.key] = entry.value;
          final parts = entry.key.split('_');
          if (parts.length == 2) {
            final colorId = int.tryParse(parts[0]);
            final sizeId = int.tryParse(parts[1]);
            if (colorId != null && sizeId != null) {
              final ctrl = matrixCellCtrl(colorId, sizeId);
              ctrl.text = '${entry.value}';
            }
          }
        }
      }
    }

    _ensureEmptyRowAtEnd();
    print('DEBUG: After _ensureEmptyRowAtEnd, items.length = ${items.length}');
    for (int i = 0; i < items.length; i++) {
      print('DEBUG: Final item $i quantity: "${items[i].quantityCtrl.text}"');
    }
    // Force a rebuild by notifying listeners AFTER everything is set up
    notifyListeners();
  }

}

