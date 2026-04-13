import '../../domain/entities/stock_variant_entity.dart';

class StockVariantModel extends StockVariantEntity {
  const StockVariantModel({
    required super.id,
    required super.productName,
    required super.colorName,
    super.imageUrl,
    super.qualityName,
    super.typeName,
    super.size,
    required super.quantityReserved,
    required super.quantityWarehouse,
  });

  factory StockVariantModel.fromJson(Map<String, dynamic> json) =>
      StockVariantModel(
        id:                  json['id'] as int,
        productName:         json['product_name'] as String? ?? '',
        colorName:           json['color_name'] as String? ?? '',
        imageUrl:            json['image_url'] as String?,
        qualityName:         json['quality_name'] as String?,
        typeName:            json['type_name'] as String?,
        size:                json['size'] as String?,
        quantityReserved:    (json['quantity_reserved'] as num?)?.toInt() ?? 0,
        quantityWarehouse:   (json['quantity_warehouse'] as num?)?.toInt() ?? 0,
      );
}
