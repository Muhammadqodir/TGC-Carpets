import 'package:equatable/equatable.dart';

class ProductionBatchItemEntity extends Equatable {
  final int id;

  /// 'order_item' | 'stock_request' | 'manual'
  final String sourceType;

  // ── Quantities ──────────────────────────────────────────────────────────
  final int plannedQuantity;
  final int? producedQuantity;
  final int? defectQuantity;
  final int? warehouseReceivedQuantity;
  final String? notes;

  // ── Source order item ────────────────────────────────────────────────────
  final int? sourceOrderItemId;
  final int? sourceOrderId;
  final int? sourceOrderQuantity;
  final String? sourceClientShopName;
  final String? sourceClientRegion;

  // ── Variant / product ────────────────────────────────────────────────────
  final int variantId;
  final String? variantSku;
  final String? variantBarcode;
  final int? productId;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final int? productColorId;
  final int? productSizeId;
  final int? productTypeId;
  final String? qualityName;
  final String? productTypeName;

  const ProductionBatchItemEntity({
    required this.id,
    required this.sourceType,
    required this.plannedQuantity,
    this.producedQuantity,
    this.defectQuantity,
    this.warehouseReceivedQuantity,
    this.notes,
    this.sourceOrderItemId,
    this.sourceOrderId,
    this.sourceOrderQuantity,
    this.sourceClientShopName,
    this.sourceClientRegion,
    required this.variantId,
    this.variantSku,
    this.variantBarcode,
    this.productId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    this.productColorId,
    this.productSizeId,
    this.productTypeId,
    this.qualityName,
    this.productTypeName,
  });

  double get plannedSqm {
    if (sizeLength == null || sizeWidth == null) return 0.0;
    return sizeLength! * sizeWidth! * plannedQuantity / 10000.0;
  }

  double get producedSqm {
    if (sizeLength == null || sizeWidth == null || producedQuantity == null) {
      return 0.0;
    }
    return sizeLength! * sizeWidth! * producedQuantity! / 10000.0;
  }

  @override
  List<Object?> get props => [
        id,
        sourceType,
        plannedQuantity,
        producedQuantity,
        defectQuantity,
        warehouseReceivedQuantity,
        notes,
        sourceOrderItemId,
        sourceOrderId,
        sourceOrderQuantity,
        sourceClientShopName,
        sourceClientRegion,
        variantId,
        variantSku,
        variantBarcode,
        productId,
        productName,
        colorName,
        colorImageUrl,
        sizeLength,
        sizeWidth,
        productUnit,
        productColorId,
        productSizeId,
        productTypeId,
        qualityName,
        productTypeName,
      ];
}
