import '../../domain/entities/product_quality_entity.dart';

class ProductQualityModel extends ProductQualityEntity {
  const ProductQualityModel({
    required super.id,
    required super.qualityName,
    super.density,
    super.status,
  });

  factory ProductQualityModel.fromJson(Map<String, dynamic> json) =>
      ProductQualityModel(
        id: json['id'] as int,
        qualityName: json['quality_name'] as String,
        density: json['density'] as int?,
        status: json['status'] as String? ?? 'active',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'quality_name': qualityName,
        'density': density,
        'status': status,
      };
}
