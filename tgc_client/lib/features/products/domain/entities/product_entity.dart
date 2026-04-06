import 'package:equatable/equatable.dart';
import 'product_type_entity.dart';

class ProductEntity extends Equatable {
  final int id;
  final String uuid;
  final String name;
  final String? skuCode;
  final String? barcode;
  final int? productTypeId;
  final ProductTypeEntity? productType;
  final String quality;
  final int density;
  final String color;
  final String? edge;
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
    this.barcode,
    this.productTypeId,
    this.productType,
    required this.quality,
    required this.density,
    required this.color,
    this.edge,
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
        barcode,
        productTypeId,
        productType,
        quality,
        density,
        color,
        edge,
        unit,
        status,
        imageUrl,
        stock,
        createdAt,
        updatedAt,
      ];
}
