import 'package:flutter/material.dart';

import '../../../production/domain/entities/production_batch_entity.dart';
import '../../../production/domain/entities/production_batch_item_entity.dart';
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
  final List<WarehouseItemRow> _items = [WarehouseItemRow()];
  final TextEditingController notesCtrl = TextEditingController();
  String username = '';

  WarehouseDocumentFormController() {
    notesCtrl.addListener(_onChange);
    _hookRow(_items.first);
  }

  List<WarehouseItemRow> get items => List.unmodifiable(_items);

  // ── Row mutations ─────────────────────────────────────────────────────────

  void updateRow(WarehouseItemRow row, {bool notify = true}) {
    _ensureSentinel();
    if (notify) notifyListeners();
  }

  void removeRow(int index) {
    if (_items.length <= 1) return;
    final row = _items[index];
    _unhookRow(row);
    row.dispose();
    _items.removeAt(index);
    _ensureSentinel();
    notifyListeners();
  }

  /// Called after directly mutating a row's product / color / size fields.
  void notifyChanged() {
    _ensureSentinel();
    notifyListeners();
  }

  /// Called when the user picks a product/color/size on the sentinel row.
  /// Promotes the sentinel to a real row and appends a fresh sentinel.
  void promoteIfSentinel(WarehouseItemRow row) {
    final isSentinel = _items.last == row;
    if (isSentinel && row.isFilled) {
      _addSentinel();
      notifyListeners();
    }
  }

  /// Imports items from a production batch. Skips variants already present.
  void addRowsFromProductionBatch(
    ProductionBatchEntity batch,
    List<ProductionBatchItemEntity> items,
  ) {
    // Remove ALL unfilled rows (sentinel + any lingering empty rows from draft
    // restore or partial edits) so they don't accumulate at the beginning.
    final toRemove = _items.where((r) => !r.isFilled).toList();
    for (final row in toRemove) {
      _unhookRow(row);
      row.dispose();
      _items.remove(row);
    }

    for (final item in items) {
      final alreadyExists = _items.any((r) {
        final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
        final rSizeId = r.selectedSize?.id ?? r.prefilledSizeId;
        return rColorId == item.productColorId && rSizeId == item.productSizeId;
      });
      if (!alreadyExists) {
        final row = WarehouseItemRow.fromBatchItem(
          item,
          batchId: batch.id,
          batchTitle: batch.batchTitle,
        );
        _hookRow(row);
        _items.add(row);
      }
    }

    _ensureSentinel();
    notifyListeners();
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Returns only the filled rows (with product or prefill selected).
  List<WarehouseItemRow> get filledItems =>
      _items.where((r) => r.isFilled).toList();

  /// Called when a QR code is scanned.
  /// If a row with the same [sourceBatchItemId] already exists its quantity is
  /// incremented by 1 (re-scan = +1). Otherwise a new row is created with
  /// [initialQuantity] = 1, using the prefill data from [item].
  void addOrIncrementFromQr(
    ProductionBatchItemEntity item, {
    required int batchId,
    required String batchTitle,
  }) {
    // Look for an existing row from the same batch item
    final existing = _items.firstWhere(
      (r) => r.sourceBatchItemId == item.id,
      orElse: () => WarehouseItemRow(sourceBatchItemId: -1),
    );

    if (existing.sourceBatchItemId == item.id) {
      // Increment qty
      final current = int.tryParse(existing.quantityCtrl.text) ?? 1;
      existing.quantityCtrl.text = '${current + 1}';
      notifyListeners();
      return;
    }

    // New row — remove all unfilled rows first (same as batch import)
    final toRemove = _items.where((r) => !r.isFilled).toList();
    for (final row in toRemove) {
      _unhookRow(row);
      row.dispose();
      _items.remove(row);
    }

    final row = WarehouseItemRow.fromBatchItem(
      item,
      batchId: batchId,
      batchTitle: batchTitle,
      initialQuantity: 1,
    );
    _hookRow(row);
    _items.add(row);
    _ensureSentinel();
    notifyListeners();
  }

  // ── Bulk restore (used by DraftService) ──────────────────────────────────

  /// Replaces current items + notes in one shot without triggering mid-restore
  /// listeners. Safe to call from an async context before the widget is shown.
  void restoreFrom({
    required List<WarehouseItemRow> newItems,
    required String notes,
  }) {
    for (final row in _items) {
      _unhookRow(row);
      row.dispose();
    }
    _items.clear();

    notesCtrl.removeListener(_onChange);
    notesCtrl.text = notes;
    notesCtrl.addListener(_onChange);

    for (final row in newItems) {
      _hookRow(row);
      _items.add(row);
    }
    _ensureSentinel();
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addSentinel() {
    final row = WarehouseItemRow();
    _hookRow(row);
    _items.add(row);
  }

  void _ensureSentinel() {
    if (_items.isEmpty || _items.last.isFilled) {
      _addSentinel();
    }
  }

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
    for (final row in _items) {
      _unhookRow(row);
      row.dispose();
    }
    super.dispose();
  }
}
