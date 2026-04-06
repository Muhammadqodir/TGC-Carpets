import '../../domain/entities/product_entity.dart';
import 'product_type_model.dart';

class ProductModel extends ProductEntity {
  const ProductModel({
    required super.id,
    required super.uuid,
    required super.name,
    super.skuCode,
    super.barcode,
    super.productTypeId,
    super.productType,
    required super.quality,
    required super.density,
    required super.color,
    super.edge,
    required super.unit,
    required super.status,
    super.imageUrl,
    super.stock,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as int,
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        skuCode: json['sku_code'] as String?,
        barcode: json['barcode'] as String?,
        productTypeId: json['product_type_id'] as int?,
        productType: json['product_type'] != null
            ? ProductTypeModel.fromJson(
                json['product_type'] as Map<String, dynamic>,
              )
            : null,
        quality: json['quality'] as String,
        density: json['density'] as int,
        color: json['color'] as String,
        edge: json['edge'] as String?,
        unit: json['unit'] as String,
        status: json['status'] as String,
        imageUrl: json['image_url'] as String?,
        stock: json['stock'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'sku_code': skuCode,
        'barcode': barcode,
        'product_type_id': productTypeId,
        'quality': quality,
        'density': density,
        'color': color,
        'edge': edge,
        'unit': unit,
        'status': status,
        'image_url': imageUrl,
        'stock': stock,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
