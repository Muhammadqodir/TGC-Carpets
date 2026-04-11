import '../../domain/entities/production_batch_item_entity.dart';

class ProductionBatchItemModel extends ProductionBatchItemEntity {
  const ProductionBatchItemModel({
    required super.id,
    required super.sourceType,
    super.sourceOrderItemId,
    super.sourceOrderId,
    super.sourceOrderNumber,
    super.sourceClientShopName,
    super.sourceOrderedQuantity,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    super.productId,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.sizeLength,
    super.sizeWidth,
    super.productUnit,
    super.productColorId,
    super.productSizeId,
    super.qualityName,
    super.productTypeName,
    required super.plannedQuantity,
    super.producedQuantity = 0,
    super.defectQuantity = 0,
    super.warehouseReceivedQuantity = 0,
    super.notes,
  });

  factory ProductionBatchItemModel.fromJson(Map<String, dynamic> json) {
    final variantMap = json['variant'] as Map<String, dynamic>?;
    final colorMap = variantMap?['product_color'] as Map<String, dynamic>?;
    final productMap = colorMap?['product'] as Map<String, dynamic>?;
    final colorInfoMap = colorMap?['color'] as Map<String, dynamic>?;
    final sizeMap = variantMap?['product_size'] as Map<String, dynamic>?;
    final productTypeMap = productMap?['product_type'] as Map<String, dynamic>?;

    // Source order item info
    final sourceOrderItemMap =
        json['source_order_item'] as Map<String, dynamic>?;
    final sourceOrderMap =
        sourceOrderItemMap?['order'] as Map<String, dynamic>?;
    final sourceClientMap =
        sourceOrderMap?['client'] as Map<String, dynamic>?;

    return ProductionBatchItemModel(
      id: json['id'] as int,
      sourceType: json['source_type'] as String,
      sourceOrderItemId: sourceOrderItemMap?['id'] as int?,
      sourceOrderId: sourceOrderMap?['id'] as int?,
      sourceOrderNumber: sourceOrderMap?['id'] as int?,
      sourceClientShopName: sourceClientMap?['shop_name'] as String?,
      sourceOrderedQuantity: sourceOrderItemMap?['quantity'] as int?,
      variantId: variantMap?['id'] as int? ?? 0,
      variantSku: variantMap?['sku_code'] as String?,
      variantBarcode: variantMap?['barcode_value'] as String?,
      productId: productMap?['id'] as int?,
      productName: productMap?['name'] as String? ?? '',
      colorName: colorInfoMap?['name'] as String?,
      colorImageUrl: colorMap?['image_url'] as String?,
      sizeLength: sizeMap?['length'] as int?,
      sizeWidth: sizeMap?['width'] as int?,
      productUnit: productMap?['unit'] as String?,
      productColorId: colorMap?['id'] as int?,
      productSizeId: sizeMap?['id'] as int?,
      qualityName: productMap?['quality_name'] as String?,
      productTypeName: productTypeMap?['type'] as String?,
      plannedQuantity: json['planned_quantity'] as int,
      producedQuantity: json['produced_quantity'] as int? ?? 0,
      defectQuantity: json['defect_quantity'] as int? ?? 0,
      warehouseReceivedQuantity:
          json['warehouse_received_quantity'] as int? ?? 0,
      notes: json['notes'] as String?,
    );
  }
}
