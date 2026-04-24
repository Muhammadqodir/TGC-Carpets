import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:tgc_client/features/products/data/models/product_size_model.dart';
import 'package:tgc_client/features/products/domain/entities/product_color_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';

import 'order_item_row.dart';

/// A product + colour pairing that represents one row in the matrix order form.
class MatrixProductRow {
  final ProductEntity product;
  final ProductColorEntity color;

  const MatrixProductRow({required this.product, required this.color});
}

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
  List<Map<String, dynamic>> get sheetMatrixFilledItems {
    final result = <Map<String, dynamic>>[];
    for (final row in items) {
      if (_isRowEmpty(row)) continue;
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
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

  List<ProductSizeEntity> getUniqueSizesList() {
    List<ProductSizeEntity> sizes = [];
    for (final item in items) {
      if (item.prefilledSizeId != null) {
        if (!sizes.any((s) => s.id == item.prefilledSizeId)) {
          sizes.add(item.selectedSize!);
        }
      }
    }
    return sizes.toList();
  }

  List<OrderItemRow> getUniqueItems() {
    List<OrderItemRow> uniqueItems = [];
    for (final item in items) {
      bool isUnique = true;
      for (final uniqueItem in uniqueItems) {
        if (item.selectedProduct?.id == uniqueItem.selectedProduct?.id &&
            item.selectedColor?.id == uniqueItem.selectedColor?.id) {
          isUnique = false;
          break;
        }
      }
      if (isUnique) {
        uniqueItems.add(item);
      }
    }
    return uniqueItems.toList();
  }

  // ── Matrix mode ─────────────────────────────────────────────────────────────

  final List<MatrixProductRow> matrixProductRows = [];
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
      });
      return c;
    });
  }

  /// Adds a product+colour row. Returns false if the colour is already a row.
  bool addMatrixProductRow(ProductEntity product, ProductColorEntity color) {
    if (matrixProductRows.any((r) => r.color.id == color.id)) return false;
    matrixProductRows.add(MatrixProductRow(product: product, color: color));
    for (final s in matrixSizeColumns) {
      matrixCellCtrl(color.id, s.id);
    }
    notifyListeners();
    return true;
  }

  /// Adds a size column. Returns false if the size is already a column.
  bool addMatrixSizeColumn(ProductSizeEntity size) {
    if (matrixSizeColumns.any((s) => s.id == size.id)) return false;
    matrixSizeColumns.add(size);
    for (final r in matrixProductRows) {
      matrixCellCtrl(r.color.id, size.id);
    }
    notifyListeners();
    return true;
  }

  /// Removes the product+colour row and disposes its cell controllers.
  void removeMatrixProductRow(int colorId) {
    matrixProductRows.removeWhere((r) => r.color.id == colorId);
    for (final s in matrixSizeColumns) {
      _disposeMatrixCell(_matrixKey(colorId, s.id));
    }
    notifyListeners();
  }

  /// Removes the size column and disposes its cell controllers.
  void removeMatrixSizeColumn(int sizeId) {
    matrixSizeColumns.removeWhere((s) => s.id == sizeId);
    for (final r in matrixProductRows) {
      _disposeMatrixCell(_matrixKey(r.color.id, sizeId));
    }
    notifyListeners();
  }

  void _disposeMatrixCell(String key) {
    _matrixCellCtrls[key]?.dispose();
    _matrixCellCtrls.remove(key);
    _matrixQty.remove(key);
  }

  /// Item maps ready for submission — only cells with quantity > 0.
  List<Map<String, dynamic>> get matrixFilledItems {
    final result = <Map<String, dynamic>>[];
    for (final row in matrixProductRows) {
      for (final size in matrixSizeColumns) {
        final qty = _matrixQty[_matrixKey(row.color.id, size.id)] ?? 0;
        if (qty > 0) {
          result.add({
            'product_color_id': row.color.id,
            'product_size_id': size.id,
            'quantity': qty,
          });
        }
      }
    }
    return result;
  }
}
