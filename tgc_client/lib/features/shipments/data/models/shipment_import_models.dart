import '../../domain/entities/shipment_import_entities.dart';

class ShipmentImportClientModel extends ShipmentImportClientEntity {
  const ShipmentImportClientModel({
    required super.id,
    required super.shopName,
    required super.region,
    super.contactName,
    required super.itemCount,
  });

  factory ShipmentImportClientModel.fromJson(Map<String, dynamic> json) {
    return ShipmentImportClientModel(
      id: json['id'] as int,
      shopName: json['shop_name'] as String,
      region: json['region'] as String,
      contactName: json['contact_name'] as String?,
      itemCount: json['item_count'] as int? ?? 0,
    );
  }
}

class ShipmentImportQualityModel extends ShipmentImportQualityEntity {
  const ShipmentImportQualityModel({
    required super.qualityName,
    required super.itemCount,
  });

  factory ShipmentImportQualityModel.fromJson(Map<String, dynamic> json) {
    return ShipmentImportQualityModel(
      qualityName: json['quality_name'] as String,
      itemCount: json['item_count'] as int? ?? 0,
    );
  }
}

class ShipmentImportItemModel extends ShipmentImportItemEntity {
  const ShipmentImportItemModel({
    required super.orderItemId,
    required super.variantId,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.qualityName,
    super.typeName,
    super.sizeLength,
    super.sizeWidth,
    super.productUnit,
    super.edgeCode,
    super.edgeTitle,
    required super.availableQuantity,
    super.orderRemaining,
    super.stockQuantity,
    super.producedForClient,
    super.productionBatchItemId,
    super.unmatchedReason,
  });

  /// Parses both shapes the scan endpoint returns: a matched order line, and
  /// an unmatched carpet, where `order_item_id` is null because the order
  /// line does not exist yet.
  factory ShipmentImportItemModel.fromJson(Map<String, dynamic> json) {
    return ShipmentImportItemModel(
      orderItemId: json['order_item_id'] as int?,
      variantId: json['variant_id'] as int,
      productName: json['product_name'] as String? ?? '',
      colorName: json['color_name'] as String?,
      colorImageUrl: json['color_image_url'] as String?,
      qualityName: json['quality_name'] as String?,
      typeName: json['type_name'] as String?,
      sizeLength: json['size_length'] as int?,
      sizeWidth: json['size_width'] as int?,
      productUnit: json['product_unit'] as String?,
      edgeCode: json['edge_code'] as String?,
      edgeTitle: json['edge_title'] as String?,
      availableQuantity: json['available_quantity'] as int? ?? 0,
      orderRemaining: json['order_remaining'] as int?,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      producedForClient: json['produced_for_client'] as String?,
      productionBatchItemId: json['production_batch_item_id'] as int?,
      unmatchedReason: json['reason'] as String?,
    );
  }
}
