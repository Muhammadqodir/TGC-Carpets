import 'package:equatable/equatable.dart';
import 'product_color_entity.dart';
import 'product_quality_entity.dart';
import 'product_type_entity.dart';

class ProductEntity extends Equatable {
  final int id;
  final String uuid;
  final String name;
  final int? productTypeId;
  final ProductTypeEntity? productType;
  final int? productQualityId;
  final ProductQualityEntity? productQuality;
  final String unit;
  final String status;
  final List<ProductColorEntity> productColors;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductEntity({
    required this.id,
    required this.uuid,
    required this.name,
    this.productTypeId,
    this.productType,
    this.productQualityId,
    this.productQuality,
    required this.unit,
    required this.status,
    this.productColors = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  ProductEntity copyWith({
    String? status,
    List<ProductColorEntity>? productColors,
  }) =>
      ProductEntity(
        id: id,
        uuid: uuid,
        name: name,
        productTypeId: productTypeId,
        productType: productType,
        productQualityId: productQualityId,
        productQuality: productQuality,
        unit: unit,
        status: status ?? this.status,
        productColors: productColors ?? this.productColors,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        uuid,
        name,
        productTypeId,
        productType,
        productQualityId,
        productQuality,
        unit,
        status,
        productColors,
        createdAt,
        updatedAt,
      ];
}
