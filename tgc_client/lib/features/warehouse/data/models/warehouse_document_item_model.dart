import '../../domain/entities/warehouse_document_item_entity.dart';

class WarehouseDocumentItemModel extends WarehouseDocumentItemEntity {
  const WarehouseDocumentItemModel({
    required super.id,
    required super.productId,
    required super.productName,
    super.productSkuCode,
    super.productUnit,
    super.productSizeId,
    super.productSizeLabel,
    required super.quantity,
    super.notes,
  });

  factory WarehouseDocumentItemModel.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>?;
    final sizeMap    = json['product_size'] as Map<String, dynamic>?;
    return WarehouseDocumentItemModel(
      id: json['id'] as int,
      productId: productMap?['id'] as int? ?? 0,
      productName: productMap?['name'] as String? ?? '',
      productSkuCode: productMap?['sku_code'] as String?,
      productUnit: productMap?['unit'] as String?,
      productSizeId: sizeMap?['id'] as int?,
      productSizeLabel: sizeMap != null
          ? '${sizeMap['length']}x${sizeMap['width']}'
          : null,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
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
        if (productSizeId != null)
          'product_size': {
            'id': productSizeId,
          },
        'quantity': quantity,
        'notes': notes,
      };
}
