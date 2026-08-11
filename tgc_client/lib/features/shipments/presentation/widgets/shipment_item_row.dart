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

  /// Max shippable quantity = order qty - already shipped qty.
  final int availableQuantity;

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

  double get rowSqm =>
      (sizeLength != null && sizeWidth != null)
          ? sizeLength! * sizeWidth! * parsedQuantity / 10000.0
          : parsedQuantity.toDouble();

  void dispose() {
    quantityCtrl.dispose();
  }
}
