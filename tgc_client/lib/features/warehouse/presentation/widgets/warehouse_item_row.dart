import 'package:flutter/material.dart';

import '../../../production/domain/entities/production_batch_item_entity.dart';
import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';

/// View-layer model that holds the mutable state for a single line item in
/// the "add warehouse document" form (both mobile and desktop variants).
///
/// Rows can be populated either by the user picking a product (manual entry)
/// or by importing items from a completed [ProductionBatchItemEntity].
/// Prefilled rows match the sentinel/prefill pattern used in [BatchItemRow].
class WarehouseItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductColorEntity? selectedColor;
  ProductSizeEntity? selectedSize;
  final TextEditingController quantityCtrl;
  final TextEditingController notesCtrl;

  // ── Prefill (batch import) ────────────────────────────────────────────────
  final int?    prefilledColorId;
  final int?    prefilledSizeId;
  final int?    prefilledProductId;
  final String? prefilledProductName;
  final String? prefilledColorName;
  final String? prefilledColorImageUrl;
  final int?    prefilledProductTypeId;
  final int?    prefilledSizeLength;
  final int?    prefilledSizeWidth;
  final String? prefilledQualityName;
  final String? prefilledTypeName;

  // ── Source tracking (import from production batch) ────────────────────────
  final int?    sourceBatchId;
  final int?    sourceBatchItemId;
  final String? sourceBatchTitle;
  final String? sourceClientShopName;
  final String? sourceClientRegion;
  final String? sourceType;

  /// The produced_quantity value from the source batch item (for display).
  final int? producedQuantity;

  WarehouseItemRow({
    this.prefilledColorId,
    this.prefilledSizeId,
    this.prefilledProductId,
    this.prefilledProductName,
    this.prefilledColorName,
    this.prefilledColorImageUrl,
    this.prefilledProductTypeId,
    this.prefilledSizeLength,
    this.prefilledSizeWidth,
    this.prefilledQualityName,
    this.prefilledTypeName,
    this.sourceBatchId,
    this.sourceBatchItemId,
    this.sourceBatchTitle,
    this.sourceClientShopName,
    this.sourceClientRegion,
    this.sourceType,
    this.producedQuantity,
    int initialQuantity = 1,
  })  : quantityCtrl = TextEditingController(text: '$initialQuantity'),
        notesCtrl = TextEditingController();

  /// Creates a [WarehouseItemRow] pre-populated from a [ProductionBatchItemEntity].
  /// Uses [producedQuantity] as the default receive quantity. Falls back to
  /// [plannedQuantity] if produced_quantity is null.
  factory WarehouseItemRow.fromBatchItem(
    ProductionBatchItemEntity item, {
    required int batchId,
    required String batchTitle,
    int? initialQuantity,
  }) {
    final qty = initialQuantity ?? (item.producedQuantity ?? item.plannedQuantity);
    return WarehouseItemRow(
      prefilledColorId: item.productColorId,
      prefilledSizeId: item.productSizeId,
      prefilledProductId: item.productId,
      prefilledProductName: item.productName,
      prefilledColorName: item.colorName,
      prefilledColorImageUrl: item.colorImageUrl,
      prefilledProductTypeId: item.productTypeId,
      prefilledSizeLength: item.sizeLength,
      prefilledSizeWidth: item.sizeWidth,
      prefilledQualityName: item.qualityName,
      prefilledTypeName: item.productTypeName,
      sourceBatchId: batchId,
      sourceBatchItemId: item.id,
      sourceBatchTitle: batchTitle,
      sourceClientShopName: item.sourceClientShopName,
      sourceClientRegion: item.sourceClientRegion,
      sourceType: item.sourceType,
      producedQuantity: item.producedQuantity,
      initialQuantity: qty > 0 ? qty : 1,
    );
  }

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Whether this row has enough data to be included in the document.
  bool get isFilled => selectedProduct != null || prefilledColorId != null;

  /// Quality display — entity first, then prefill fallback.
  String? get qualityName =>
      selectedProduct?.productQuality?.qualityName ?? prefilledQualityName;

  /// Product type display — entity first, then prefill fallback.
  String? get typeName =>
      selectedProduct?.productType?.type ?? prefilledTypeName;

  /// Formatted size dimensions from prefill.
  String? get prefilledSizeDimensions =>
      prefilledSizeLength != null && prefilledSizeWidth != null
          ? '$prefilledSizeLength×$prefilledSizeWidth'
          : null;

  void dispose() {
    quantityCtrl.dispose();
    notesCtrl.dispose();
  }
}
