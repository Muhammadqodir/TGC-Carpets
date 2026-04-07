import '../../domain/entities/product_variant_entity.dart';

class ProductVariantModel extends ProductVariantEntity {
  const ProductVariantModel({
    required super.id,
    super.barcodeValue,
    required super.productId,
    super.productName,
    super.productSkuCode,
    super.productUnit,
    super.productSizeId,
    super.sizeLength,
    super.sizeWidth,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    final productMap = json['product']      as Map<String, dynamic>?;
    final sizeMap    = json['product_size'] as Map<String, dynamic>?;
    return ProductVariantModel(
      id: json['id'] as int,
      barcodeValue: json['barcode_value'] as String?,
      productId: productMap?['id'] as int? ?? 0,
      productName: productMap?['name'] as String?,
      productSkuCode: productMap?['sku_code'] as String?,
      productUnit: productMap?['unit'] as String?,
      productSizeId: sizeMap?['id'] as int?,
      sizeLength: sizeMap?['length'] as int?,
      sizeWidth: sizeMap?['width'] as int?,
    );
  }
}
