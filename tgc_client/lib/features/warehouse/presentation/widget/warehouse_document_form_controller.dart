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
  }

  // ── Item mutations ──────────────────────────────────────────────────────

  void addItem() {
    final row = WarehouseItemRow();
    _hookRow(row);
    items.add(row);
    notifyListeners();
  }

  void removeItem(int index) {
    if (items.length == 1) return;
    _unhookRow(items[index]);
    items[index].dispose();
    items.removeAt(index);
    notifyListeners();
  }

  /// Called after directly mutating a row's product / color / size fields.
  void notifyChanged() => notifyListeners();

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
