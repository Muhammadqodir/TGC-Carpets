import '../../domain/entities/product_color_entity.dart';

class ProductColorModel extends ProductColorEntity {
  const ProductColorModel({
    required super.id,
    required super.colorId,
    required super.colorName,
    super.imageUrl,
  });

  factory ProductColorModel.fromJson(Map<String, dynamic> json) {
    final color = json['color'] as Map<String, dynamic>? ?? {};
    return ProductColorModel(
      id: json['id'] as int,
      colorId: color['id'] as int? ?? 0,
      colorName: color['name'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
    );
  }
}
