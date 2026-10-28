import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_entity.dart';
import '../../domain/entities/shipment_import_entities.dart';
import 'shipment_item_row.dart';

/// Outcome of [ShipmentFormController.addOrIncrementItem], used by the QR
/// scanner UI to decide what feedback to show.
enum ScanAddResult { added, incremented }

/// Holds all mutable state for the "add shipment" form.
///
/// Owned by [AddShipmentPage] and passed down to the desktop layout.
/// Notifies listeners on every change so the UI rebuilds automatically.
class ShipmentFormController extends ChangeNotifier {
  final List<ShipmentItemRow> _items = [];
  final TextEditingController notesCtrl = TextEditingController();

  /// The order that was imported (null = manual / no import yet).
  OrderEntity? importedOrder;

  ShipmentFormController() {
    notesCtrl.addListener(_onChange);
  }

  List<ShipmentItemRow> get items => List.unmodifiable(_items);

  // ── Row mutations ─────────────────────────────────────────────────────────

  /// Replaces all current rows with items from [order].
  /// Rows that have no remaining quantity are skipped.
  /// [selectedItemIds] — when non-null, only those order-item IDs are imported.
  void importFromOrder(
    OrderEntity order, {
    Set<int>? selectedItemIds,
  }) {
    _clearRows();
    importedOrder = order;

    for (final item in order.items) {
      if (selectedItemIds != null && !selectedItemIds.contains(item.id)) {
        continue;
      }
      final alreadyShipped = item.shippedQuantity ?? 0;
      if (alreadyShipped >= item.quantity) continue; // fully shipped — skip

      final incoming = ShipmentItemRow.fromOrderItem(item);
      final existing = _rowOf(incoming.variantId);
      if (existing == null) {
        _hookRow(incoming);
        _items.add(incoming);
      } else {
        // Same product on another line of the order: one row, both lines.
        existing.orderLines.addAll(incoming.orderLines);
        existing.quantityCtrl.text =
            '${existing.parsedQuantity + incoming.parsedQuantity}';
        incoming.dispose();
      }
    }

    notifyListeners();
  }

  /// Replaces all current rows with items from the stock import wizard,
  /// one row per product however many order lines it covers.
  void importFromStock(List<ShipmentImportItemEntity> items) {
    _clearRows();
    importedOrder = null;

    for (final item in items) {
      if (item.availableQuantity <= 0) continue;
      final existing = _rowOf(item.variantId);
      if (existing == null) {
        final row = ShipmentItemRow.fromImportItem(item);
        _hookRow(row);
        _items.add(row);
      } else {
        existing.absorbLineOf(item);
        existing.quantityCtrl.text =
            '${existing.parsedQuantity + item.availableQuantity}';
      }
    }

    notifyListeners();
  }

  /// Called for each carpet the QR scanner resolves: +1 on the product's
  /// row, or a new row of 1. One row per product — the order line the server
  /// picked joins the row's lines, so the same carpet on three of the
  /// client's orders is one row of 3, not three rows. Never capped: carpets
  /// past what the client owes still ship, beyond the order, and the scanner
  /// has already asked before handing such a carpet over.
  ScanAddResult addOrIncrementItem(ShipmentImportItemEntity item) {
    final row = _rowOf(item.variantId);

    if (row != null) {
      row.absorbLineOf(item);
      row.scanned = true;
      row.quantityCtrl.text = '${row.parsedQuantity + 1}';
      row.addScannedBatchItem(item.productionBatchItemId);
      if (item.producedForClient != null) {
        row.producedForClients.add(item.producedForClient!);
      }
      notifyListeners();
      return ScanAddResult.incremented;
    }

    final created = ShipmentItemRow.fromImportItem(
      item,
      initialQuantity: 1,
      scanned: true,
    );
    created.addScannedBatchItem(item.productionBatchItemId);
    if (item.producedForClient != null) {
      created.producedForClients.add(item.producedForClient!);
    }
    _hookRow(created);
    _items.add(created);
    notifyListeners();
    return ScanAddResult.added;
  }

  /// The row of [variantId], or null.
  ShipmentItemRow? rowOf(int variantId) => _rowOf(variantId);

  ShipmentItemRow? _rowOf(int variantId) {
    for (final r in _items) {
      if (r.variantId == variantId) return r;
    }
    return null;
  }

  void removeRow(int index) {
    if (index < 0 || index >= _items.length) return;
    final row = _items[index];
    _unhookRow(row);
    row.dispose();
    _items.removeAt(index);
    notifyListeners();
  }

  void notifyChanged() {
    notifyListeners();
  }

  // ── Draft restore / clear ─────────────────────────────────────────────────

  /// Replaces every row and the note with data read back from a saved draft.
  ///
  /// [importedOrder] stays null: a draft carries only the rows, and the one
  /// live import path ([importFromStock]) leaves it null too.
  void restoreFrom({
    required List<ShipmentItemRow> newItems,
    required String notes,
  }) {
    _clearRows();
    _setNotes(notes);

    for (final row in newItems) {
      final existing = _rowOf(row.variantId);
      if (existing == null) {
        _hookRow(row);
        _items.add(row);
        continue;
      }
      // Drafts from before one-row-per-product hold the same carpet on
      // several rows: fold them into one.
      for (final line in row.orderLines) {
        if (!existing.orderLines.any((l) => l.orderItemId == line.orderItemId)) {
          existing.orderLines.add(line);
        }
      }
      existing.quantityCtrl.text =
          '${existing.parsedQuantity + row.parsedQuantity}';
      existing.scanned = existing.scanned || row.scanned;
      existing.scannedBatchItemIds.addAll(row.scannedBatchItemIds);
      existing.producedForClients.addAll(row.producedForClients);
      final total = row.clientOpenRemaining;
      if (total != null &&
          (existing.clientOpenRemaining == null ||
              total > existing.clientOpenRemaining!)) {
        existing.clientOpenRemaining = total;
      }
      row.dispose();
    }

    notifyListeners();
  }

  /// Resets the form to its initial blank state.
  void clearForm() {
    _clearRows();
    _setNotes('');
    notifyListeners();
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Every carpet on the form beyond what its client's orders owe.
  int get totalBeyondClientOrders =>
      _items.fold<int>(0, (sum, r) => sum + r.beyondOrder);

  List<ShipmentItemRow> get filledItems =>
      _items.where((r) => r.parsedQuantity > 0).toList();

  /// Quantity already on the form per order line, never past what a line
  /// owes. Sent with each scan so the server offers the client's next open
  /// line instead of one this form has already filled.
  Map<int, int> get quantitiesByOrderItem {
    final quantities = <int, int>{};
    for (final row in _items) {
      row.filledLines.forEach((lineId, quantity) {
        quantities[lineId] = (quantities[lineId] ?? 0) + quantity;
      });
    }
    return quantities;
  }

  int get totalQuantity =>
      _items.fold(0, (sum, r) => sum + r.parsedQuantity);

  double get totalSqm => _items.fold(0.0, (sum, r) => sum + r.rowSqm);

  // ── Private helpers ───────────────────────────────────────────────────────

  void _clearRows() {
    for (final row in _items) {
      _unhookRow(row);
      row.dispose();
    }
    _items.clear();
    importedOrder = null;
  }

  /// Sets the note without the write itself counting as a user edit.
  void _setNotes(String notes) {
    notesCtrl.removeListener(_onChange);
    notesCtrl.text = notes;
    notesCtrl.addListener(_onChange);
  }

  void _hookRow(ShipmentItemRow row) {
    row.quantityCtrl.addListener(_onChange);
  }

  void _unhookRow(ShipmentItemRow row) {
    row.quantityCtrl.removeListener(_onChange);
  }

  void _onChange() => notifyListeners();

  @override
  void dispose() {
    notesCtrl.dispose();
    for (final row in _items) {
      _unhookRow(row);
      row.dispose();
    }
    super.dispose();
  }
}
