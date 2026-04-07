import '../../domain/entities/product_variant_entity.dart';

class ProductVariantModel extends ProductVariantEntity {
  const ProductVariantModel({
    required super.id,
    super.barcodeValue,
    super.skuCode,
    required super.productColorId,
    super.productId,
    super.productName,
    super.colorName,
    super.productUnit,
    super.productSizeId,
    super.sizeLength,
    super.sizeWidth,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    final pcMap      = json['product_color'] as Map<String, dynamic>?;
    final productMap = pcMap?['product']     as Map<String, dynamic>?;
    final colorMap   = pcMap?['color']       as Map<String, dynamic>?;
    final sizeMap    = json['product_size']  as Map<String, dynamic>?;
    return ProductVariantModel(
      id:             json['id'] as int,
      barcodeValue:   json['barcode_value'] as String?,
      skuCode:        json['sku_code'] as String?,
      productColorId: pcMap?['id'] as int? ?? 0,
      productId:      productMap?['id'] as int?,
      productName:    productMap?['name'] as String?,
      colorName:      colorMap?['name'] as String?,
      productUnit:    productMap?['unit'] as String?,
      productSizeId:  sizeMap?['id'] as int?,
      sizeLength:     sizeMap?['length'] as int?,
      sizeWidth:      sizeMap?['width'] as int?,
    );
  }
}
