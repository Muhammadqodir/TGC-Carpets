import '../../domain/entities/order_item_entity.dart';

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.id,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    required super.productId,
    required super.productName,
    super.colorName,
    super.sizeLength,
    super.sizeWidth,
    super.productUnit,
    required super.quantity,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final variantMap     = json['variant']       as Map<String, dynamic>?;
    final colorMap       = variantMap?['product_color'] as Map<String, dynamic>?;
    final productMap     = colorMap?['product']         as Map<String, dynamic>?;
    final colorInfoMap   = colorMap?['color']            as Map<String, dynamic>?;
    final sizeMap        = variantMap?['product_size']   as Map<String, dynamic>?;

    return OrderItemModel(
      id:            json['id'] as int,
      variantId:     variantMap?['id'] as int? ?? 0,
      variantSku:    variantMap?['sku_code'] as String?,
      variantBarcode: variantMap?['barcode_value'] as String?,
      productId:     productMap?['id'] as int?,
      productName:   productMap?['name'] as String? ?? '',
      colorName:     colorInfoMap?['name'] as String?,
      sizeLength:    sizeMap?['length'] as int?,
      sizeWidth:     sizeMap?['width']  as int?,
      productUnit:   productMap?['unit'] as String?,
      quantity:      json['quantity'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':       id,
        'variant':  {'id': variantId},
        'quantity': quantity,
      };
}
