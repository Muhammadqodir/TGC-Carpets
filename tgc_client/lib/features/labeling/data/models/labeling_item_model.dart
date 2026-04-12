import '../../domain/entities/labeling_item_entity.dart';

class LabelingItemModel extends LabelingItemEntity {
  const LabelingItemModel({
    required super.id,
    required super.batchId,
    super.batchTitle,
    required super.plannedQuantity,
    required super.producedQuantity,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.sizeLength,
    super.sizeWidth,
    super.qualityName,
    super.productTypeName,
  });

  factory LabelingItemModel.fromJson(Map<String, dynamic> json) {
    final variantMap     = json['variant']              as Map<String, dynamic>?;
    final colorMap       = variantMap?['product_color'] as Map<String, dynamic>?;
    final productMap     = colorMap?['product']         as Map<String, dynamic>?;
    final colorInfoMap   = colorMap?['color']           as Map<String, dynamic>?;
    final sizeMap        = variantMap?['product_size']  as Map<String, dynamic>?;
    final productTypeMap = productMap?['product_type']  as Map<String, dynamic>?;

    return LabelingItemModel(
      id:              json['id'] as int,
      batchId:         json['production_batch_id'] as int,
      batchTitle:      json['batch_title'] as String?,
      plannedQuantity: json['planned_quantity'] as int,
      producedQuantity: (json['produced_quantity'] as int?) ?? 0,
      variantId:       variantMap?['id'] as int? ?? 0,
      variantSku:      variantMap?['sku_code'] as String?,
      variantBarcode:  variantMap?['barcode_value'] as String?,
      productName:     productMap?['name'] as String? ?? '',
      colorName:       colorInfoMap?['name'] as String?,
      colorImageUrl:   colorMap?['image_url'] as String?,
      sizeLength:      sizeMap?['length'] as int?,
      sizeWidth:       sizeMap?['width']  as int?,
      qualityName:     productMap?['quality_name'] as String?,
      productTypeName: productTypeMap?['type'] as String?,
    );
  }
}
