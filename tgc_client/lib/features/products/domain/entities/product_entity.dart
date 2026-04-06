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

  ProductEntity copyWith({
    String? status,
    String? imageUrl,
    int? stock,
  }) =>
      ProductEntity(
        id: id,
        uuid: uuid,
        name: name,
        skuCode: skuCode,
        productTypeId: productTypeId,
        productType: productType,
        productQualityId: productQualityId,
        productQuality: productQuality,
        color: color,
        unit: unit,
        status: status ?? this.status,
        imageUrl: imageUrl ?? this.imageUrl,
        stock: stock ?? this.stock,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

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
