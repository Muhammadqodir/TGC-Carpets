import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_item_entity.dart';
import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../domain/entities/production_batch_item_entity.dart';

/// View-layer model for a single item row in the production batch form.
///
/// In edit mode, rows are pre-populated with server-side IDs via the
/// `prefilled*` fields so existing items render correctly before any
/// entity is re-picked.
class BatchItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity?      selectedProduct;
  ProductColorEntity? selectedColor;
  ProductSizeEntity?  selectedSize;
  final TextEditingController quantityCtrl;

  // ── Prefill (edit mode) ───────────────────────────────────────────────────
  final int?    prefilledColorId;
  final int?    prefilledSizeId;
  final String? prefilledProductName;
  final String? prefilledColorName;
  final String? prefilledColorImageUrl;
  final int?    prefilledProductTypeId;
  final int?    prefilledSizeLength;
  final int?    prefilledSizeWidth;

  // ── Source (import from order) ────────────────────────────────────────────
  final int?    sourceOrderId;
  final int?    sourceOrderItemId;
  final String? sourceClientName;

  // ── Extra display fields ──────────────────────────────────────────────────
  final String? prefilledQualityName;
  final String? prefilledTypeName;

  BatchItemRow({
    this.prefilledColorId,
    this.prefilledSizeId,
    this.prefilledProductName,
    this.prefilledColorName,
    this.prefilledColorImageUrl,
    this.prefilledProductTypeId,
    this.prefilledSizeLength,
    this.prefilledSizeWidth,
    this.sourceOrderId,
    this.sourceOrderItemId,
    this.sourceClientName,
    this.prefilledQualityName,
    this.prefilledTypeName,
    int initialQuantity = 1,
  }) : quantityCtrl = TextEditingController(text: '$initialQuantity');

  /// Creates a [BatchItemRow] pre-populated from an [OrderItemEntity].
  factory BatchItemRow.fromOrderItem(
    OrderItemEntity item, {
    required int orderId,
    String? clientName,
  }) =>
      BatchItemRow(
        prefilledColorId: item.productColorId,
        prefilledSizeId: item.productSizeId,
        prefilledProductName: item.productName,
        prefilledColorName: item.colorName,
        prefilledColorImageUrl: item.colorImageUrl,
        prefilledProductTypeId: item.productTypeId,
        prefilledSizeLength: item.sizeLength,
        prefilledSizeWidth: item.sizeWidth,
        sourceOrderId: orderId,
        sourceOrderItemId: item.id,
        sourceClientName: clientName,
        prefilledQualityName: item.qualityName,
        prefilledTypeName: item.productTypeName,
        initialQuantity: item.remainingQuantity ?? item.quantity,
      );

  /// Creates a [BatchItemRow] pre-populated from a [ProductionBatchItemEntity]
  /// (used when loading an existing batch for editing).
  factory BatchItemRow.fromBatchItem(ProductionBatchItemEntity item) =>
      BatchItemRow(
        prefilledColorId: item.productColorId,
        prefilledSizeId: item.productSizeId,
        prefilledProductName: item.productName,
        prefilledColorName: item.colorName,
        prefilledColorImageUrl: item.colorImageUrl,
        prefilledProductTypeId: item.productTypeId,
        prefilledSizeLength: item.sizeLength,
        prefilledSizeWidth: item.sizeWidth,
        sourceOrderId: item.sourceOrderId,
        sourceOrderItemId: item.sourceOrderItemId,
        sourceClientName: item.sourceClientShopName,
        prefilledQualityName: item.qualityName,
        prefilledTypeName: item.productTypeName,
        initialQuantity: item.plannedQuantity,
      );

  /// Quality name — from selected product or prefill.
  String? get qualityName =>
      selectedProduct?.productQuality?.qualityName ?? prefilledQualityName;

  /// Product type — from selected product or prefill.
  String? get typeName =>
      selectedProduct?.productType?.type ?? prefilledTypeName;

  void dispose() => quantityCtrl.dispose();

  bool get isFilled => selectedProduct != null || prefilledColorId != null;

  String? get prefilledSizeDimensions =>
      prefilledSizeLength != null && prefilledSizeWidth != null
          ? '${prefilledSizeWidth}×${prefilledSizeLength}'
          : null;

  String get label {
    if (selectedProduct != null) {
      final parts = <String>[selectedProduct!.name];
      if (selectedColor != null) parts.add(selectedColor!.colorName);
      if (selectedSize != null) parts.add(selectedSize!.dimensions);
      return parts.join(' / ');
    }
    if (prefilledProductName != null) {
      final parts = <String>[prefilledProductName!];
      if (prefilledColorName != null) parts.add(prefilledColorName!);
      final dim = prefilledSizeDimensions;
      if (dim != null) parts.add(dim);
      return parts.join(' / ');
    }
    return 'Mahsulot tanlanmagan';
  }
}
