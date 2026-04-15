import 'package:equatable/equatable.dart';

class OrderItemEntity extends Equatable {
  final int id;
  final int variantId;
  final String? variantSku;
  final String? variantBarcode;
  final int? productId;
  final String productName;
  final String? colorName;
  /// The color image URL returned by the server (product_color.image_url).
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final int quantity;
  /// The product_color.id — required when re-submitting an edit.
  final int productColorId;
  /// The product_size.id — required when the variant has a size.
  final int? productSizeId;
  /// product.product_type_id — needed to open the size picker in edit mode.
  final int? productTypeId;
  /// product.productQuality.quality_name — shown in the Sifat column.
  final String? qualityName;
  /// product.productType.type — shown in the Tur column.
  final String? productTypeName;
  /// How many units of this item have been planned in non-cancelled production batches.
  final int? plannedQuantity;
  /// How many units of this item still need to be put into production.
  /// Calculated on the backend as: quantity - sum(planned_quantity in non-cancelled batches).
  final int? remainingQuantity;
  /// How many units of this item have already been shipped.
  /// Calculated on the backend as: sum(shipment_items.quantity).
  final int? shippedQuantity;
  /// How many units have been received into the warehouse from production.
  final int? warehouseReceivedQuantity;

  const OrderItemEntity({
    required this.id,
    required this.variantId,
    this.variantSku,
    this.variantBarcode,
    required this.productId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    required this.quantity,
    required this.productColorId,
    this.productSizeId,
    this.productTypeId,
    this.qualityName,
    this.productTypeName,
    this.plannedQuantity,
    this.remainingQuantity,
    this.shippedQuantity,
    this.warehouseReceivedQuantity,
  });

  String get variantLabel {
    final parts = <String>[productName];
    if (colorName != null) parts.add(colorName!);
    if (sizeLength != null && sizeWidth != null) {
      parts.add('${sizeLength}x$sizeWidth');
    }
    return parts.join(' / ');
  }

  @override
  List<Object?> get props => [
        id,
        variantId,
        variantSku,
        variantBarcode,
        productId,
        productName,
        colorName,
        colorImageUrl,
        sizeLength,
        sizeWidth,
        productUnit,
        quantity,
        productColorId,
        productSizeId,
        plannedQuantity,
        remainingQuantity,
        shippedQuantity,
        warehouseReceivedQuantity,
        productTypeId,
        qualityName,
        productTypeName,
        remainingQuantity,
        shippedQuantity,
      ];
}
