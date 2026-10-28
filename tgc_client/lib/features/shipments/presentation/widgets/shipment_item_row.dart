import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_item_entity.dart';
import '../../domain/entities/shipment_import_entities.dart';

/// View-layer model for a single line item in the "add shipment" form.
///
/// Each row maps to one [OrderItemEntity] and holds the editable quantity.
///
/// No price: a warehouse worker loading a lorry has no business guessing what
/// a client pays, and asking them for it held up the scan flow. A shipment is
/// created unpriced and the pricing feature fills it in afterwards, which is
/// also what unlocks the hisob-faktura.
class ShipmentItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  // ── Identity ──────────────────────────────────────────────────────────────
  /// Null for a scanned carpet the client has no open order line for. The
  /// backend creates that line when the shipment is submitted — see
  /// ShipmentService::createOrderLinesForScannedItems().
  final int? orderItemId;
  final int variantId;

  /// True when this row came from scanning the label on a physical carpet.
  /// Sent to the backend, which only repairs missing order lines and missing
  /// warehouse stock for rows that carry it.
  final bool scanned;

  /// One entry per carpet scanned into this row, naming the production batch
  /// item its label resolved to. Two carpets off the same batch item appear
  /// twice; a label shape that names no single carpet contributes nothing.
  ///
  /// The backend moves the production record of each of these onto the line
  /// this row ships against, so a carpet made for another client stops
  /// counting as ready for them once it leaves — see
  /// ShipmentService::reattributeScannedProduction().
  final List<int> scannedBatchItemIds = [];

  /// Shop names of the other clients the carpets scanned into this row were
  /// produced for. Shown on the row, so the conflict the scanner asked about
  /// stays visible on the form until the shipment is saved.
  final Set<String> producedForClients = {};

  // ── Display fields (from order item) ─────────────────────────────────────
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final String? qualityName;
  final String? typeName;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final String? edgeCode;
  final String? edgeTitle;

  /// What the source offered when the row was added: unshipped on the order
  /// line, capped by stock for rows from the stock wizard.
  final int availableQuantity;

  /// What the order line still owes, regardless of stock. Null for rows with
  /// no order line, and for rows from servers that did not report it.
  final int? orderRemaining;

  /// Which order the line belongs to, for the caption under the name.
  final int? orderId;
  final String? orderDate;

  /// What the client owed for this carpet across all open orders when it
  /// was scanned. Null for wizard rows and older servers.
  final int? clientOpenRemaining;

  // ── Editable fields ───────────────────────────────────────────────────────
  final TextEditingController quantityCtrl;

  ShipmentItemRow({
    required this.orderItemId,
    required this.variantId,
    this.scanned = false,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.qualityName,
    this.typeName,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    this.edgeCode,
    this.edgeTitle,
    required this.availableQuantity,
    this.orderRemaining,
    this.orderId,
    this.orderDate,
    this.clientOpenRemaining,
    int initialQuantity = 1,
  }) : quantityCtrl = TextEditingController(text: '$initialQuantity');

  factory ShipmentItemRow.fromImportItem(
    ShipmentImportItemEntity item, {
    int? initialQuantity,
    bool scanned = false,
  }) {
    return ShipmentItemRow(
      orderItemId: item.orderItemId,
      variantId: item.variantId,
      scanned: scanned,
      productName: item.productName,
      colorName: item.colorName,
      colorImageUrl: item.colorImageUrl,
      qualityName: item.qualityName,
      typeName: item.typeName,
      sizeLength: item.sizeLength,
      sizeWidth: item.sizeWidth,
      productUnit: item.productUnit,
      edgeCode: item.edgeCode,
      edgeTitle: item.edgeTitle,
      availableQuantity: item.availableQuantity,
      orderRemaining: item.isOnClientOrder
          ? (item.orderRemaining ?? item.availableQuantity)
          : null,
      orderId: item.orderId,
      orderDate: item.orderDate,
      clientOpenRemaining: item.clientOpenRemaining,
      initialQuantity: initialQuantity ??
          (item.availableQuantity > 0 ? item.availableQuantity : 1),
    );
  }

  factory ShipmentItemRow.fromOrderItem(
    OrderItemEntity item,
  ) {
    final alreadyShipped = item.shippedQuantity ?? 0;
    final remaining = item.quantity - alreadyShipped;
    final stockAvailable = item.stockAvailable ?? 0;
    
    // Available quantity is the minimum of what's remaining from order and what's in stock
    final available = remaining.clamp(0, stockAvailable).clamp(0, item.quantity);

    return ShipmentItemRow(
      orderItemId: item.id,
      variantId: item.variantId,
      productName: item.productName,
      colorName: item.colorName,
      colorImageUrl: item.colorImageUrl,
      qualityName: item.qualityName,
      typeName: item.productTypeName,
      sizeLength: item.sizeLength,
      sizeWidth: item.sizeWidth,
      productUnit: item.productUnit,
      edgeCode: item.edgeCode,
      edgeTitle: item.edgeTitle,
      availableQuantity: available,
      orderRemaining: remaining < 0 ? 0 : remaining,
      initialQuantity: available > 0 ? available : 1,
    );
  }

  /// Records one more scanned carpet against this row. Ignores a null id —
  /// the `PB{n} VAR{n}` label shape names a variant and no particular carpet,
  /// so there is no production row for the backend to move.
  void addScannedBatchItem(int? batchItemId) {
    if (batchItemId != null) scannedBatchItemIds.add(batchItemId);
  }

  String? get sizeLabel =>
      sizeLength != null && sizeWidth != null ? '$sizeWidth×$sizeLength' : null;

  int get parsedQuantity => int.tryParse(quantityCtrl.text.trim()) ?? 0;

  /// Carpets on this row beyond what ITS order line still owes. Not the same
  /// as beyond the client's order: the backend first puts them on the
  /// client's other open orders for the carpet, and only the rest on the
  /// shipment's own order (ShipmentService::splitOverOrderedLines) — see
  /// ShipmentFormController.beyondClientOrders. 0 for rows with no order
  /// line, which are wholly off-order ([isOffOrder]).
  int get beyondLine {
    if (orderItemId == null) return 0;
    final owed = orderRemaining ?? availableQuantity;
    final excess = parsedQuantity - owed;
    return excess > 0 ? excess : 0;
  }

  /// A carpet this client has no order line for; one is opened on save.
  bool get isOffOrder => orderItemId == null;

  double get rowSqm =>
      (sizeLength != null && sizeWidth != null)
          ? sizeLength! * sizeWidth! * parsedQuantity / 10000.0
          : parsedQuantity.toDouble();

  void dispose() {
    quantityCtrl.dispose();
  }
}
