import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_item_entity.dart';

/// View-layer model for a single line item in the "add shipment" form.
///
/// Each row maps to one [OrderItemEntity] and holds editable quantity + price.
class ShipmentItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  // ── Identity ──────────────────────────────────────────────────────────────
  final int orderItemId;
  final int variantId;

  // ── Display fields (from order item) ─────────────────────────────────────
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final String? qualityName;
  final String? typeName;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;

  /// Max shippable quantity = order qty - already shipped qty.
  final int availableQuantity;

  // ── Editable fields ───────────────────────────────────────────────────────
  final TextEditingController quantityCtrl;
  final TextEditingController priceCtrl;

  ShipmentItemRow({
    required this.orderItemId,
    required this.variantId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.qualityName,
    this.typeName,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    required this.availableQuantity,
    int initialQuantity = 1,
    double? initialPrice,
  })  : quantityCtrl =
            TextEditingController(text: '$initialQuantity'),
        priceCtrl = TextEditingController(
            text: initialPrice != null ? initialPrice.toStringAsFixed(2) : '');

  factory ShipmentItemRow.fromOrderItem(
    OrderItemEntity item, {
    double? lastPrice,
  }) {
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
      availableQuantity: available,
      initialQuantity: available > 0 ? available : 1,
      initialPrice: lastPrice,
    );
  }

  String? get sizeLabel =>
      sizeLength != null && sizeWidth != null ? '${sizeLength}×$sizeWidth' : null;

  double get parsedPrice =>
      double.tryParse(priceCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;

  int get parsedQuantity => int.tryParse(quantityCtrl.text.trim()) ?? 0;

  double get rowSqm =>
      (sizeLength != null && sizeWidth != null)
          ? sizeLength! * sizeWidth! * parsedQuantity / 10000.0
          : parsedQuantity.toDouble();

  double get lineTotal => productUnit == 'piece'
      ? parsedPrice * parsedQuantity
      : parsedPrice * rowSqm;

  void dispose() {
    quantityCtrl.dispose();
    priceCtrl.dispose();
  }
}
