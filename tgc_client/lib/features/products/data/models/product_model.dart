import '../../domain/entities/product_entity.dart';
import 'product_color_model.dart';
import 'product_quality_model.dart';
import 'product_type_model.dart';

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.uuid,
    required super.name,
    super.productTypeId,
    super.productType,
    super.productQualityId,
    super.productQuality,
    required super.unit,
    required super.status,
    super.productColors = const [],
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as int,
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        productTypeId: json['product_type_id'] as int?,
        productType: json['product_type'] != null
            ? ProductTypeModel.fromJson(
                json['product_type'] as Map<String, dynamic>,
              )
            : null,
        productQualityId: json['product_quality_id'] as int?,
        productQuality: json['product_quality'] != null
            ? ProductQualityModel.fromJson(
                json['product_quality'] as Map<String, dynamic>,
              )
            : null,
        unit: json['unit'] as String,
        status: json['status'] as String,
        productColors: (json['product_colors'] as List<dynamic>? ?? [])
            .map((e) => ProductColorModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'product_type_id': productTypeId,
        'product_quality_id': productQualityId,
        'unit': unit,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
