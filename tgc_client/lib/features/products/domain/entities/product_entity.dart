import 'package:equatable/equatable.dart';
import 'product_quality_entity.dart';
import 'product_type_entity.dart';

class ProductEntity extends Equatable {
  final int id;
  final String uuid;
  final String name;
  final String? skuCode;
  final int? productTypeId;
  final ProductTypeEntity? productType;
  final int? productQualityId;
  final ProductQualityEntity? productQuality;
  final String color;
  final String unit;
  final String status;
  final String? imageUrl;
  final int? stock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductEntity({
    required this.id,
    required this.uuid,
    required this.name,
    this.skuCode,
    this.productTypeId,
    this.productType,
    this.productQualityId,
    this.productQuality,
    required this.color,
    required this.unit,
    required this.status,
    this.imageUrl,
    this.stock,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [
        id,
        uuid,
        name,
        skuCode,
        productTypeId,
        productType,
        productQualityId,
        productQuality,
        color,
        unit,
        status,
        imageUrl,
        stock,
        createdAt,
        updatedAt,
      ];
}
