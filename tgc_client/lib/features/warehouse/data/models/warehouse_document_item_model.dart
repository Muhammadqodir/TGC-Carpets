import '../../domain/entities/warehouse_document_item_entity.dart';

class WarehouseDocumentItemModel extends WarehouseDocumentItemEntity {
  const WarehouseDocumentItemModel({
    required super.id,
    required super.productId,
    required super.productName,
    super.productSkuCode,
    super.productUnit,
    required super.quantity,
    super.notes,
  });

  factory WarehouseDocumentItemModel.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] as Map<String, dynamic>?;
    return WarehouseDocumentItemModel(
      id: json['id'] as int,
      productId: productMap?['id'] as int? ?? 0,
      productName: productMap?['name'] as String? ?? '',
      productSkuCode: productMap?['sku_code'] as String?,
      productUnit: productMap?['unit'] as String?,
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
        'quantity': quantity,
        'notes': notes,
      };
}
