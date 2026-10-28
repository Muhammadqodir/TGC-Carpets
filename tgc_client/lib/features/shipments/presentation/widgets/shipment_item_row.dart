import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_item_entity.dart';
import '../../domain/entities/shipment_import_entities.dart';

/// One of the client's order lines a form row ships against.
class ShipmentOrderLine {
  final int orderItemId;
  final int? orderId;

  /// `YYYY-MM-DD`, as the server sends it.
  final String? orderDate;

  /// What this line still owed when it joined the row, regardless of stock.
  final int remaining;

  const ShipmentOrderLine({
    required this.orderItemId,
    this.orderId,
    this.orderDate,
    required this.remaining,
  });

  Map<String, dynamic> toJson() => {
        'order_item_id': orderItemId,
        'order_id': orderId,
        'order_date': orderDate,
        'remaining': remaining,
      };

  factory ShipmentOrderLine.fromJson(Map<String, dynamic> json) =>
      ShipmentOrderLine(
        orderItemId: json['order_item_id'] as int,
        orderId: json['order_id'] as int?,
        orderDate: json['order_date'] as String?,
        remaining: json['remaining'] as int? ?? 0,
      );
}

/// One piece of a row as it is posted: an order line (or none) and how many
/// carpets go on it, with the scanned labels that belong to those carpets.
class ShipmentRowPiece {
  final int? orderItemId;
  final int quantity;
  final List<int> scannedBatchItemIds;

  const ShipmentRowPiece(this.orderItemId, this.quantity, this.scannedBatchItemIds);
}

/// View-layer model for one product on the "add shipment" form.
///
/// One row per product (variant), since October 2026. A client often has
/// several open orders for the same carpet (ABDUBANNO AKA had six for one),
/// and a row per order line showed the same carpet three times with three
/// different limits. The row now holds every line it ships against in
/// [orderLines]; [pieces] splits it back into lines when the shipment is
/// posted, and the backend spreads whatever the lines cannot take onto the
/// client's other open orders, then onto the shipment's own order
/// (ShipmentService::splitOverOrderedLines).
///
/// No price: a warehouse worker loading a lorry has no business guessing what
/// a client pays. A shipment is created unpriced and the pricing feature fills
/// it in afterwards, which is also what unlocks the hisob-faktura.
class ShipmentItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  // ── Identity ──────────────────────────────────────────────────────────────
  final int variantId;

  /// The client's order lines this row ships against, in the order they
  /// were added (the scanner's choice first). Empty for a carpet the client
  /// has no open order line for; the backend opens one on save.
  final List<ShipmentOrderLine> orderLines = [];

  /// True when any carpet on this row came from scanning its label. Sent to
  /// the backend, which only repairs missing order lines and missing
  /// warehouse stock for rows that carry it.
  bool scanned;

  /// One entry per carpet scanned into this row, naming the production batch
  /// item its label resolved to. Two carpets off the same batch item appear
  /// twice; a label shape that names no single carpet contributes nothing.
  ///
  /// The backend moves the production record of each of these onto the line
  /// it ships against, so a carpet made for another client stops counting as
  /// ready for them once it leaves — see
  /// ShipmentService::reattributeScannedProduction().
  final List<int> scannedBatchItemIds = [];

  /// Shop names of the other clients the carpets scanned into this row were
  /// produced for. Shown on the row, so the conflict the scanner asked about
  /// stays visible on the form until the shipment is saved.
  final Set<String> producedForClients = {};

  /// What the client owed for this carpet across ALL open orders at the last
  /// scan. Null for wizard rows and older servers, where [orderLines] are the
  /// best the form knows.
  int? clientOpenRemaining;

  // ── Display fields ────────────────────────────────────────────────────────
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

  // ── Editable fields ───────────────────────────────────────────────────────
  final TextEditingController quantityCtrl;

  ShipmentItemRow({
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
    this.clientOpenRemaining,
    int initialQuantity = 1,
  }) : quantityCtrl = TextEditingController(text: '$initialQuantity');

  factory ShipmentItemRow.fromImportItem(
    ShipmentImportItemEntity item, {
    int? initialQuantity,
    bool scanned = false,
  }) {
    return ShipmentItemRow(
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
      clientOpenRemaining: item.clientOpenRemaining,
      initialQuantity: initialQuantity ??
          (item.availableQuantity > 0 ? item.availableQuantity : 1),
    )..absorbLineOf(item);
  }

  factory ShipmentItemRow.fromOrderItem(OrderItemEntity item) {
    final alreadyShipped = item.shippedQuantity ?? 0;
    final remaining = item.quantity - alreadyShipped;
    final stockAvailable = item.stockAvailable ?? 0;

    // Starts at what both the order and the stock allow.
    final available =
        remaining.clamp(0, stockAvailable).clamp(0, item.quantity);

    return ShipmentItemRow(
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
      initialQuantity: available > 0 ? available : 1,
    )..orderLines.add(ShipmentOrderLine(
        orderItemId: item.id,
        remaining: remaining < 0 ? 0 : remaining,
      ));
  }

  /// Adds the order line [item] resolved to, unless the row already has it,
  /// and keeps the largest client-wide total seen.
  void absorbLineOf(ShipmentImportItemEntity item) {
    final lineId = item.orderItemId;
    if (lineId != null && !orderLines.any((l) => l.orderItemId == lineId)) {
      orderLines.add(ShipmentOrderLine(
        orderItemId: lineId,
        orderId: item.orderId,
        orderDate: item.orderDate,
        remaining: item.orderRemaining ?? item.availableQuantity,
      ));
    }

    final total = item.clientOpenRemaining;
    if (total != null &&
        (clientOpenRemaining == null || total > clientOpenRemaining!)) {
      clientOpenRemaining = total;
    }
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

  /// A carpet this client has no order line for; one is opened on save.
  bool get isOffOrder => orderLines.isEmpty;

  /// What the lines on this row still owe together.
  int get owedOnLines => orderLines.fold(0, (sum, l) => sum + l.remaining);

  /// What the client owes for this carpet, as far as the form knows.
  int get owed {
    final total = clientOpenRemaining ?? 0;
    return total > owedOnLines ? total : owedOnLines;
  }

  /// Carpets beyond everything the client still owes for this product — what
  /// the backend puts on the shipment's own order. 0 for off-order rows,
  /// which are wholly beyond the order and say so through [isOffOrder].
  int get beyondOrder {
    if (isOffOrder) return 0;
    final excess = parsedQuantity - owed;
    return excess > 0 ? excess : 0;
  }

  /// The row as posted: each line takes what it owes, in order, and the
  /// rest rides on the first line for the backend to spread (other open
  /// orders first, then the shipment's own order). An off-order row is one
  /// piece with no order line. Scanned labels follow the carpets in order.
  List<ShipmentRowPiece> get pieces {
    final quantity = parsedQuantity;
    if (quantity <= 0) return const [];

    if (isOffOrder) {
      return [ShipmentRowPiece(null, quantity, List.of(scannedBatchItemIds))];
    }

    final amounts = <int, int>{};
    var left = quantity;
    for (final line in orderLines) {
      final take = left < line.remaining ? left : line.remaining;
      if (take > 0) amounts[line.orderItemId] = take;
      left -= take;
    }
    if (left > 0) {
      final first = orderLines.first.orderItemId;
      amounts[first] = (amounts[first] ?? 0) + left;
    }

    var offset = 0;
    return [
      for (final entry in amounts.entries)
        () {
          final end = (offset + entry.value).clamp(0, scannedBatchItemIds.length);
          final ids = scannedBatchItemIds.sublist(
              offset.clamp(0, scannedBatchItemIds.length), end);
          offset += entry.value;
          return ShipmentRowPiece(entry.key, entry.value, ids);
        }(),
    ];
  }

  /// How much of this row sits on each of its lines, never past what a line
  /// owes — sent with each scan so the server offers the next line instead.
  Map<int, int> get filledLines {
    final filled = <int, int>{};
    var left = parsedQuantity;
    for (final line in orderLines) {
      final take = left < line.remaining ? left : line.remaining;
      if (take > 0) filled[line.orderItemId] = take;
      left -= take;
    }
    return filled;
  }

  double get rowSqm =>
      (sizeLength != null && sizeWidth != null)
          ? sizeLength! * sizeWidth! * parsedQuantity / 10000.0
          : parsedQuantity.toDouble();

  void dispose() {
    quantityCtrl.dispose();
  }
}
