import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_entity.dart';
import 'shipment_item_row.dart';

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
  void importFromOrder(
    OrderEntity order,
    Map<int, double> lastPrices,
  ) {
    _clearRows();
    importedOrder = order;

    for (final item in order.items) {
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

  double get totalSqm => _items.fold(0.0, (sum, r) {
        if (r.sizeLength == null || r.sizeWidth == null) return sum;
        return sum + r.sizeLength! * r.sizeWidth! * r.parsedQuantity / 10000.0;
      });

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
