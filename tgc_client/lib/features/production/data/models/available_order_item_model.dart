import '../../domain/entities/available_order_item_entity.dart';

class AvailableOrderItemModel extends AvailableOrderItemEntity {
  const AvailableOrderItemModel({
    required super.orderItemId,
    required super.orderId,
    required super.orderNumber,
    super.clientShopName,
    required super.orderedQuantity,
    required super.plannedQuantity,
    required super.remainingQuantity,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.sizeLength,
    super.sizeWidth,
    super.productColorId,
    super.productSizeId,
    super.qualityName,
    super.productTypeName,
  });

  factory AvailableOrderItemModel.fromJson(Map<String, dynamic> json) {
    final variantMap = json['variant'] as Map<String, dynamic>?;
    final colorMap = variantMap?['product_color'] as Map<String, dynamic>?;
    final productMap = colorMap?['product'] as Map<String, dynamic>?;
    final colorInfoMap = colorMap?['color'] as Map<String, dynamic>?;
    final sizeMap = variantMap?['product_size'] as Map<String, dynamic>?;
    final productTypeMap = productMap?['product_type'] as Map<String, dynamic>?;

    return AvailableOrderItemModel(
      orderItemId: json['order_item_id'] as int,
      orderId: json['order_id'] as int,
      orderNumber: json['order_number'] as int,
      clientShopName: json['client_shop_name'] as String?,
      orderedQuantity: json['ordered_quantity'] as int,
      plannedQuantity: json['planned_quantity'] as int,
      remainingQuantity: json['remaining_quantity'] as int,
      variantId: variantMap?['id'] as int? ?? 0,
      variantSku: variantMap?['sku_code'] as String?,
      variantBarcode: variantMap?['barcode_value'] as String?,
      productName: productMap?['name'] as String? ?? '',
      colorName: colorInfoMap?['name'] as String?,
      colorImageUrl: colorMap?['image_url'] as String?,
      sizeLength: sizeMap?['length'] as int?,
      sizeWidth: sizeMap?['width'] as int?,
      productColorId: colorMap?['id'] as int?,
      productSizeId: sizeMap?['id'] as int?,
      qualityName: productMap?['quality_name'] as String?,
      productTypeName: productTypeMap?['type'] as String?,
    );
  }
}
