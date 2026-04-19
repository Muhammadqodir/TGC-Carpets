import '../../domain/entities/shipment_item_entity.dart';

class ShipmentItemModel extends ShipmentItemEntity {
  const ShipmentItemModel({
    required super.id,
    required super.quantity,
    required super.price,
    super.variantId,
    super.barcodeValue,
    super.skuCode,
    super.productId,
    super.productName,
    super.productUnit,
    super.productSizeLabel,
    super.sizeLength,
    super.sizeWidth,
    super.colorId,
    super.colorName,
    super.orderId,
    super.orderDate,
  });

  factory ShipmentItemModel.fromJson(Map<String, dynamic> json) {
    final variantMap  = json['variant']      as Map<String, dynamic>?;
    final productMap  = json['product']      as Map<String, dynamic>?;
    final colorMap    = json['color']        as Map<String, dynamic>?;
    final sizeLength  = variantMap?['length'] as int?;
    final sizeWidth   = variantMap?['width']  as int?;

    return ShipmentItemModel(
      id:               json['id'] as int,
      quantity:         json['quantity'] as int,
      price:            double.parse('${json['price']}'),
      variantId:        variantMap?['id'] as int?,
      barcodeValue:     variantMap?['barcode_value'] as String?,
      skuCode:          variantMap?['sku_code'] as String?,
      productId:        productMap?['id'] as int?,
      productName:      productMap?['name'] as String?,
      productUnit:      productMap?['unit'] as String?,
      productSizeLabel: (sizeLength != null && sizeWidth != null)
          ? '${sizeLength}x${sizeWidth}'
          : null,
      sizeLength:       sizeLength,
      sizeWidth:        sizeWidth,
      colorId:   colorMap?['id'] as int?,
      colorName: colorMap?['name'] as String?,
      orderId:   (json['order'] as Map<String, dynamic>?)?['id'] as int?,
      orderDate: (json['order'] as Map<String, dynamic>?)?['order_date'] != null
          ? DateTime.parse(
              (json['order'] as Map<String, dynamic>)['order_date'] as String)
          : null,
    );
  }
}
