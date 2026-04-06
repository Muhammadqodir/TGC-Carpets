import '../../domain/entities/product_type_entity.dart';

class ProductTypeModel extends ProductTypeEntity {
  const ProductTypeModel({required super.id, required super.type});

  factory ProductTypeModel.fromJson(Map<String, dynamic> json) =>
      ProductTypeModel(
        id: json['id'] as int,
        type: json['type'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type};
}
