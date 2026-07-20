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
  /// [lastPrices] maps variantId → last known price.
  /// [selectedItemIds] — when non-null, only those order-item IDs are imported.
  void importFromOrder(
    OrderEntity order,
    Map<int, double> lastPrices, {
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
        lastPrice: lastPrices[item.variantId],
      );
      _hookRow(row);
      _items.add(row);
    }

    notifyListeners();
  }

  /// Replaces all current rows with items from the stock import wizard.
  /// [lastPrices] maps variantId → last known price for the client.
  void importFromStock(
    List<ShipmentImportItemEntity> items,
    Map<int, double> lastPrices,
  ) {
    _clearRows();
    importedOrder = null;

    for (final item in items) {
      if (item.availableQuantity <= 0) continue;
      final row = ShipmentItemRow.fromImportItem(
        item,
        lastPrice: lastPrices[item.variantId],
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
  ScanAddResult addOrIncrementItem(ShipmentImportItemEntity item,
      {double? lastPrice}) {
    final existing = _items.where((r) => r.orderItemId == item.orderItemId);
    if (existing.isNotEmpty) {
      final row = existing.first;
      final current = row.parsedQuantity;
      // Use the just-fetched availableQuantity (not row.availableQuantity,
      // a snapshot from when the row was first added) since it reflects
      // stock/order state as of this scan.
      if (current >= item.availableQuantity) {
        return ScanAddResult.limitReached;
      }
      row.quantityCtrl.text = '${current + 1}';
      notifyListeners();
      return ScanAddResult.incremented;
    }

    final row = ShipmentItemRow.fromImportItem(
      item,
      lastPrice: lastPrice,
      initialQuantity: 1,
    );
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

  // ── Computed helpers ──────────────────────────────────────────────────────

  List<ShipmentItemRow> get filledItems =>
      _items.where((r) => r.parsedQuantity > 0).toList();

  double get grandTotal =>
      _items.fold(0.0, (sum, r) => sum + r.lineTotal);

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

  void _hookRow(ShipmentItemRow row) {
    row.quantityCtrl.addListener(_onChange);
    row.priceCtrl.addListener(_onChange);
  }

  void _unhookRow(ShipmentItemRow row) {
    row.quantityCtrl.removeListener(_onChange);
    row.priceCtrl.removeListener(_onChange);
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
