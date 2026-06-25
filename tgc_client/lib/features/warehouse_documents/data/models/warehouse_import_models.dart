import '../../domain/entities/warehouse_import_entities.dart';

class ImportClientModel extends ImportClientEntity {
  const ImportClientModel({
    required super.id,
    required super.shopName,
    required super.region,
    super.contactName,
    required super.itemCount,
  });

  factory ImportClientModel.fromJson(Map<String, dynamic> json) {
    return ImportClientModel(
      id: json['id'] as int,
      shopName: json['shop_name'] as String,
      region: json['region'] as String,
      contactName: json['contact_name'] as String?,
      itemCount: json['item_count'] as int? ?? 0,
    );
  }
}

class ImportQualityModel extends ImportQualityEntity {
  const ImportQualityModel({
    required super.qualityName,
    required super.itemCount,
  });

  factory ImportQualityModel.fromJson(Map<String, dynamic> json) {
    return ImportQualityModel(
      qualityName: json['quality_name'] as String,
      itemCount: json['item_count'] as int? ?? 0,
    );
  }
}

class ImportItemModel extends ImportItemEntity {
  const ImportItemModel({
    required super.id,
    required super.sourceType,
    required super.plannedQuantity,
    super.producedQuantity,
    super.defectQuantity,
    super.warehouseReceivedQuantity,
    super.notes,
    super.sourceOrderItemId,
    super.sourceOrderId,
    super.sourceOrderQuantity,
    super.sourceClientShopName,
    super.sourceClientRegion,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    super.productId,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.sizeLength,
    super.sizeWidth,
    super.productUnit,
    super.productColorId,
    super.productSizeId,
    super.productTypeId,
    super.qualityName,
    super.productTypeName,
    super.edgeCode,
    required super.batchId,
    required super.batchTitle,
  });

  factory ImportItemModel.fromJson(Map<String, dynamic> json) {
    return ImportItemModel(
      id: json['id'] as int,
      batchId: json['batch_id'] as int,
      batchTitle: json['batch_title'] as String,
      sourceType: json['source_type'] as String? ?? 'manual',
      plannedQuantity: json['planned_quantity'] as int? ?? 0,
      producedQuantity: json['produced_quantity'] as int?,
      defectQuantity: json['defect_quantity'] as int?,
      warehouseReceivedQuantity: json['warehouse_received_quantity'] as int?,
      notes: json['notes'] as String?,
      sourceOrderItemId: json['source_order_item_id'] as int?,
      sourceOrderId: json['source_order_id'] as int?,
      sourceOrderQuantity: json['source_order_quantity'] as int?,
      sourceClientShopName: json['source_client_shop_name'] as String?,
      sourceClientRegion: json['source_client_region'] as String?,
      variantId: json['variant_id'] as int? ?? 0,
      variantSku: json['variant_sku'] as String?,
      variantBarcode: json['variant_barcode'] as String?,
      productId: json['product_id'] as int?,
      productName: json['product_name'] as String? ?? '',
      colorName: json['color_name'] as String?,
      colorImageUrl: json['color_image_url'] as String?,
      sizeLength: json['size_length'] as int?,
      sizeWidth: json['size_width'] as int?,
      productUnit: json['product_unit'] as String?,
      productColorId: json['product_color_id'] as int?,
      productSizeId: json['product_size_id'] as int?,
      productTypeId: json['product_type_id'] as int?,
      qualityName: json['quality_name'] as String?,
      productTypeName: json['product_type_name'] as String?,
      edgeCode: json['edge_code'] as String?,
    );
  }
}
