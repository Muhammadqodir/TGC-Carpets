import 'package:equatable/equatable.dart';

class ShipmentImportClientEntity extends Equatable {
  final int id;
  final String shopName;
  final String region;
  final String? contactName;
  final int itemCount;

  const ShipmentImportClientEntity({
    required this.id,
    required this.shopName,
    required this.region,
    this.contactName,
    required this.itemCount,
  });

  String get displayName =>
      contactName != null ? '$shopName ($contactName)' : shopName;

  @override
  List<Object?> get props => [id, shopName, region, contactName, itemCount];
}

class ShipmentImportQualityEntity extends Equatable {
  final String qualityName;
  final int itemCount;

  const ShipmentImportQualityEntity({
    required this.qualityName,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [qualityName, itemCount];
}

/// A single shippable order item ready for import into the shipment form.
class ShipmentImportItemEntity extends Equatable {
  final int orderItemId;
  final int variantId;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final String? qualityName;
  final String? typeName;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final String? edgeCode;
  final String? edgeTitle;

  /// Available to ship: min(order_qty - shipped_qty, stock_qty). Pre-computed on backend.
  final int availableQuantity;

  const ShipmentImportItemEntity({
    required this.orderItemId,
    required this.variantId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.qualityName,
    this.typeName,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    this.edgeCode,
    this.edgeTitle,
    required this.availableQuantity,
  });

  String? get sizeLabel =>
      sizeLength != null && sizeWidth != null ? '$sizeWidth×$sizeLength' : null;

  @override
  List<Object?> get props => [
        orderItemId, variantId, productName, colorName, colorImageUrl,
        qualityName, typeName, sizeLength, sizeWidth, productUnit,
        edgeCode, edgeTitle, availableQuantity,
      ];
}
