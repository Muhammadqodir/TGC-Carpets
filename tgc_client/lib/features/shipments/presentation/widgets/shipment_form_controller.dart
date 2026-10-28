import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_entity.dart';
import '../../domain/entities/shipment_import_entities.dart';
import 'shipment_item_row.dart';

/// Outcome of [ShipmentFormController.addOrIncrementItem], used by the QR
/// scanner UI to decide what feedback to show.
enum ScanAddResult { added, incremented, limitReached }

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

      final row = ShipmentItemRow.fromOrderItem(
        item,
      );
      _hookRow(row);
      _items.add(row);
    }

    notifyListeners();
  }

  /// Replaces all current rows with items from the stock import wizard.
  void importFromStock(List<ShipmentImportItemEntity> items) {
    _clearRows();
    importedOrder = null;

    for (final item in items) {
      if (item.availableQuantity <= 0) continue;
      final row = ShipmentItemRow.fromImportItem(
        item,
      );
      _hookRow(row);
      _items.add(row);
    }

    notifyListeners();
  }

  /// Called when a QR code scanned on the "add shipment" page resolves to a
  /// shippable item. If a row for the same order item already exists its
  /// quantity is incremented by 1 (re-scan = +1, one physical carpet per
  /// scan), capped at the server-computed [ShipmentImportItemEntity.availableQuantity].
  /// Otherwise a new row is added with quantity 1, without touching existing
  /// rows (unlike [importFromOrder]/[importFromStock], which replace them).
  ScanAddResult addOrIncrementItem(ShipmentImportItemEntity item) {
    // Rows for a carpet with no order line yet cannot be matched on
    // orderItemId — they all have none — so they are matched on the variant
    // instead, among rows added the same way. Scanning the same off-order
    // carpet twice is still one row of quantity 2.
    final existing = item.isOnClientOrder
        ? _items.where((r) => r.orderItemId == item.orderItemId)
        : _items.where((r) => r.orderItemId == null && r.variantId == item.variantId);

    if (existing.isNotEmpty) {
      final row = existing.first;
      final current = row.parsedQuantity;
      // Use the just-fetched availableQuantity (not row.availableQuantity,
      // a snapshot from when the row was first added) since it reflects
      // stock/order state as of this scan. An off-order row has nothing to
      // cap against: the order line is created to fit whatever ships.
      if (item.isOnClientOrder && current >= item.availableQuantity) {
        return ScanAddResult.limitReached;
      }
      row.quantityCtrl.text = '${current + 1}';
      row.addScannedBatchItem(item.productionBatchItemId);
      if (item.producedForClient != null) {
        row.producedForClients.add(item.producedForClient!);
      }
      notifyListeners();
      return ScanAddResult.incremented;
    }

    final row = ShipmentItemRow.fromImportItem(
      item,
      initialQuantity: 1,
      scanned: true,
    );
    row.addScannedBatchItem(item.productionBatchItemId);
    if (item.producedForClient != null) {
      row.producedForClients.add(item.producedForClient!);
    }
    _hookRow(row);
    _items.add(row);
    notifyListeners();
    return ScanAddResult.added;
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
      _hookRow(row);
      _items.add(row);
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

  /// Carpets of [variantId] on this form beyond everything the client still
  /// owes for it, across all their open orders — what the backend will put
  /// on the shipment's own order. Rows past their own line but within the
  /// client's total are not counted: those carpets go on the client's next
  /// order (ShipmentService::splitOverOrderedLines).
  ///
  /// What is owed comes from the scan (clientOpenRemaining, every open line);
  /// for wizard rows, which do not carry it, the lines on the form are the
  /// best the form knows.
  int beyondClientOrders(int variantId) {
    final onOrder =
        _items.where((r) => r.variantId == variantId && !r.isOffOrder);
    if (onOrder.isEmpty) return 0;

    final loaded = onOrder.fold<int>(0, (sum, r) => sum + r.parsedQuantity);

    final scannedTotals =
        onOrder.map((r) => r.clientOpenRemaining).whereType<int>();
    final perLine = <int, int>{
      for (final r in onOrder)
        r.orderItemId!: r.orderRemaining ?? r.availableQuantity,
    };
    final fromLines = perLine.values.fold<int>(0, (sum, v) => sum + v);
    final owed = scannedTotals.isEmpty
        ? fromLines
        : [fromLines, ...scannedTotals].reduce((a, b) => a > b ? a : b);

    return loaded > owed ? loaded - owed : 0;
  }

  /// The row of [variantId] that carries the "beyond the order" note: the
  /// last on-order one, so the warning appears once rather than on every
  /// order of the same carpet.
  bool isLastOnOrderRowOf(ShipmentItemRow row) =>
      !row.isOffOrder &&
      identical(
        _items.lastWhere(
          (r) => r.variantId == row.variantId && !r.isOffOrder,
          orElse: () => row,
        ),
        row,
      );

  /// Every carpet on the form beyond what its client's orders owe.
  int get totalBeyondClientOrders => {
        for (final r in _items)
          if (!r.isOffOrder) r.variantId,
      }.fold<int>(0, (sum, v) => sum + beyondClientOrders(v));

  List<ShipmentItemRow> get filledItems =>
      _items.where((r) => r.parsedQuantity > 0).toList();

  /// Quantity already on the form per order line, summed over rows. Sent
  /// with each scan so the server skips lines this form has already filled.
  Map<int, int> get quantitiesByOrderItem {
    final quantities = <int, int>{};
    for (final row in _items) {
      final orderItemId = row.orderItemId;
      if (orderItemId == null) continue;
      quantities[orderItemId] =
          (quantities[orderItemId] ?? 0) + row.parsedQuantity;
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
