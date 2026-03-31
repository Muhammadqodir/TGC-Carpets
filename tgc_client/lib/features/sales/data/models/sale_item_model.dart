import '../../domain/entities/sale_item_entity.dart';

class SaleItemModel extends SaleItemEntity {
  const SaleItemModel({
    required super.id,
    required super.productId,
    required super.productName,
    super.productSkuCode,
    required super.productUnit,
    required super.quantity,
    required super.price,
    required super.subtotal,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    return SaleItemModel(
      id: json['id'] as int,
      productId: product['id'] as int? ?? 0,
      productName: product['name'] as String? ?? '',
      productSkuCode: product['sku_code'] as String?,
      productUnit: product['unit'] as String? ?? '',
      quantity: json['quantity'] as int,
      price: double.parse(json['price'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': {
          'id': productId,
          'name': productName,
          'sku_code': productSkuCode,
          'unit': productUnit,
        },
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
      };
}
