import '../../domain/entities/shipment_item_entity.dart';

class ShipmentItemModel extends ShipmentItemEntity {
  const ShipmentItemModel({
    required super.id,
    required super.quantity,
    required super.price,
    required super.total,
    super.variantId,
    super.barcodeValue,
    super.skuCode,
    super.productId,
    super.productName,
    super.productUnit,
    super.productSizeId,
    super.productSizeLabel,
    super.colorId,
    super.colorName,
  });

  factory ShipmentItemModel.fromJson(Map<String, dynamic> json) {
    final variantMap  = json['variant']      as Map<String, dynamic>?;
    final productMap  = json['product']      as Map<String, dynamic>?;
    final colorMap    = json['color']        as Map<String, dynamic>?;
    final sizeMap     = json['product_size'] as Map<String, dynamic>?;

    return ShipmentItemModel(
      id:               json['id'] as int,
      quantity:         json['quantity'] as int,
      price:            double.parse('${json['price']}'),
      total:            double.parse('${json['total']}'),
      variantId:        variantMap?['id'] as int?,
      barcodeValue:     variantMap?['barcode_value'] as String?,
      skuCode:          variantMap?['sku_code'] as String?,
      productId:        productMap?['id'] as int?,
      productName:      productMap?['name'] as String?,
      productUnit:      productMap?['unit'] as String?,
      productSizeId:    sizeMap?['id'] as int?,
      productSizeLabel: sizeMap != null
          ? '${sizeMap['length']}x${sizeMap['width']}'
          : null,
      colorId:   colorMap?['id'] as int?,
      colorName: colorMap?['name'] as String?,
    );
  }
}
