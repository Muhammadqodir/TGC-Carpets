import 'package:equatable/equatable.dart';

class ProductionBatchItemEntity extends Equatable {
  final int id;
  final String sourceType; // 'order_item' | 'stock_request' | 'manual'
  final int? sourceOrderItemId;
  final int? sourceOrderId;
  final int? sourceOrderNumber;
  final String? sourceClientShopName;
  final int? sourceOrderedQuantity;
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
  final String? qualityName;
  final String? productTypeName;
  final int plannedQuantity;
  final int producedQuantity;
  final int defectQuantity;
  final int warehouseReceivedQuantity;
  final String? notes;

  const ProductionBatchItemEntity({
    required this.id,
    required this.sourceType,
    this.sourceOrderItemId,
    this.sourceOrderId,
    this.sourceOrderNumber,
    this.sourceClientShopName,
    this.sourceOrderedQuantity,
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
    this.qualityName,
    this.productTypeName,
    required this.plannedQuantity,
    this.producedQuantity = 0,
    this.defectQuantity = 0,
    this.warehouseReceivedQuantity = 0,
    this.notes,
  });

  String get variantLabel {
    final parts = <String>[productName];
    if (colorName != null) parts.add(colorName!);
    if (sizeLength != null && sizeWidth != null) {
      parts.add('${sizeLength}x$sizeWidth');
    }
    return parts.join(' / ');
  }

  String get sourceLabel {
    if (sourceType == 'order_item' && sourceOrderNumber != null) {
      return '#$sourceOrderNumber${sourceClientShopName != null ? ' ($sourceClientShopName)' : ''}';
    }
    return 'Zaxira uchun';
  }

  double get progressPercent =>
      plannedQuantity > 0 ? producedQuantity / plannedQuantity : 0.0;

  @override
  List<Object?> get props => [
        id,
        sourceType,
        sourceOrderItemId,
        sourceOrderId,
        sourceOrderNumber,
        sourceClientShopName,
        sourceOrderedQuantity,
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
        qualityName,
        productTypeName,
        plannedQuantity,
        producedQuantity,
        defectQuantity,
        warehouseReceivedQuantity,
        notes,
      ];
}
