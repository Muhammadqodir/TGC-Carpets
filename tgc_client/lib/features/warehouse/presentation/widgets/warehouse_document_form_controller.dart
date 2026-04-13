import 'package:flutter/material.dart';

import 'warehouse_item_row.dart';

/// Shared form state for the "add warehouse document" flow.
///
/// Lives in [AddWarehouseDocumentPage] and is passed down to both the
/// mobile and desktop layout variants.  Surviving layout switches (resize)
/// is the primary reason this controller exists.
///
/// All mutations go through the public methods so that [notifyListeners] is
/// called consistently, driving auto-save and UI rebuilds.
class WarehouseDocumentFormController extends ChangeNotifier {
  final List<WarehouseItemRow> items = [];
  final TextEditingController notesCtrl = TextEditingController();
  String username = '';

  WarehouseDocumentFormController() {
    notesCtrl.addListener(_onChange);
    _ensureEmptyRowAtEnd();
  }

  // ── Item mutations ──────────────────────────────────────────────────────

  void _addItem() {
    final row = WarehouseItemRow();
    _hookRow(row);
    items.add(row);
  }

  void removeItem(int index) {
    _unhookRow(items[index]);
    items[index].dispose();
    items.removeAt(index);
    _ensureEmptyRowAtEnd();
    notifyListeners();
  }

  /// Called after directly mutating a row's product / color / size fields.
  void notifyChanged() {
    _ensureEmptyRowAtEnd();
    notifyListeners();
  }

  /// Ensures there's always at least one empty row at the end for data entry.
  void _ensureEmptyRowAtEnd() {
    // Remove trailing empty rows if more than one
    while (items.length > 1 && _isRowEmpty(items.last)) {
      final lastRow = items.removeLast();
      _unhookRow(lastRow);
      lastRow.dispose();
    }

    // Add an empty row if none exists or the last row is filled
    if (items.isEmpty || !_isRowEmpty(items.last)) {
      _addItem();
    }
  }

  /// Checks if a row is empty (no product selected).
  bool _isRowEmpty(WarehouseItemRow row) {
    return row.selectedProduct == null;
  }

  /// Returns only the filled rows (with product selected).
  List<WarehouseItemRow> get filledItems {
    return items.where((row) => !_isRowEmpty(row)).toList();
  }

  // ── Bulk restore (used by DraftService) ─────────────────────────────────

  /// Replaces current items + notes in one shot without triggering mid-restore
  /// listeners. Safe to call from an async context before the widget is shown.
  void restoreFrom({
    required List<WarehouseItemRow> newItems,
    required String notes,
  }) {
    // dispose existing
    for (final row in items) {
      _unhookRow(row);
      row.dispose();
    }
    items.clear();

    notesCtrl.removeListener(_onChange);
    notesCtrl.text = notes;
    notesCtrl.addListener(_onChange);

    for (final row in newItems) {
      _hookRow(row);
      items.add(row);
    }
    _ensureEmptyRowAtEnd();
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _hookRow(WarehouseItemRow row) {
    row.quantityCtrl.addListener(_onChange);
    row.notesCtrl.addListener(_onChange);
  }

  void _unhookRow(WarehouseItemRow row) {
    row.quantityCtrl.removeListener(_onChange);
    row.notesCtrl.removeListener(_onChange);
  }

  void _onChange() => notifyListeners();

  @override
  void dispose() {
    notesCtrl.removeListener(_onChange);
    notesCtrl.dispose();
    for (final row in items) {
      _unhookRow(row);
      row.dispose();
    }
    super.dispose();
  }
}
