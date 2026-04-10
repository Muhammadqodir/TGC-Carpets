import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    for (final row in items) {
      row.quantityCtrl.removeListener(notifyListeners);
      row.dispose();
    }
    notesCtrl.removeListener(notifyListeners);
    notesCtrl.dispose();
    super.dispose();
  }
}
