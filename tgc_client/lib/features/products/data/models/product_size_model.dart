import '../../domain/entities/product_size_entity.dart';

class ProductSizeModel extends ProductSizeEntity {
  const ProductSizeModel({
    required super.id,
    required super.length,
    required super.width,
    required super.productTypeId,
  });

  factory ProductSizeModel.fromJson(Map<String, dynamic> json) =>
      ProductSizeModel(
        id: json['id'] as int,
        length: json['length'] as int,
        width: json['width'] as int,
        productTypeId: json['product_type_id'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'product_type_id': productTypeId,
      };
}
