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
    super.colorId,
    super.colorName,
    required super.quantity,
    super.notes,
    super.variantId,
    super.barcodeValue,
  });

  factory WarehouseDocumentItemModel.fromJson(Map<String, dynamic> json) {
    final productMap  = json['product']      as Map<String, dynamic>?;
    final sizeMap     = json['product_size'] as Map<String, dynamic>?;
    final variantMap  = json['variant']      as Map<String, dynamic>?;
    final colorMap    = json['color']        as Map<String, dynamic>?;
    return WarehouseDocumentItemModel(
      id: json['id'] as int,
      productId: productMap?['id'] as int? ?? 0,
      productName: productMap?['name'] as String? ?? '',
      productSkuCode: variantMap?['sku_code'] as String?,
      productUnit: productMap?['unit'] as String?,
      productSizeId: sizeMap?['id'] as int?,
      productSizeLabel: sizeMap != null
          ? '${sizeMap['length']}x${sizeMap['width']}'
          : null,
      colorId: colorMap?['id'] as int?,
      colorName: colorMap?['name'] as String?,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
      variantId: variantMap?['id'] as int?,
      barcodeValue: variantMap?['barcode_value'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product': {
          'id': productId,
          'name': productName,
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
