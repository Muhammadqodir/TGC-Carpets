import 'package:equatable/equatable.dart';

/// Represents an order item available for production planning.
class AvailableOrderItemEntity extends Equatable {
  final int orderItemId;
  final int orderId;
  final int orderNumber;
  final String? clientShopName;
  final int orderedQuantity;
  final int plannedQuantity;
  final int remainingQuantity;
  final int variantId;
  final String? variantSku;
  final String? variantBarcode;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final int? productColorId;
  final int? productSizeId;
  final String? qualityName;
  final String? productTypeName;

  const AvailableOrderItemEntity({
    required this.orderItemId,
    required this.orderId,
    required this.orderNumber,
    this.clientShopName,
    required this.orderedQuantity,
    required this.plannedQuantity,
    required this.remainingQuantity,
    required this.variantId,
    this.variantSku,
    this.variantBarcode,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    this.productColorId,
    this.productSizeId,
    this.qualityName,
    this.productTypeName,
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
        orderItemId,
        orderId,
        orderNumber,
        clientShopName,
        orderedQuantity,
        plannedQuantity,
        remainingQuantity,
        variantId,
        variantSku,
        variantBarcode,
        productName,
        colorName,
        colorImageUrl,
        sizeLength,
        sizeWidth,
        productColorId,
        productSizeId,
        qualityName,
        productTypeName,
      ];
}
