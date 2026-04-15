import 'package:equatable/equatable.dart';

class ShipmentItemEntity extends Equatable {
  final int id;
  final int quantity;
  final double price;
  final int? variantId;
  final String? barcodeValue;
  final String? skuCode;
  final int? productId;
  final String? productName;
  final String? productUnit; // 'piece' | 'm2'
  final int? productSizeId;
  final String? productSizeLabel;
  final int? sizeLength;
  final int? sizeWidth;
  final int? colorId;
  final String? colorName;
  final int? orderId;
  final DateTime? orderDate;

  const ShipmentItemEntity({
    required this.id,
    required this.quantity,
    required this.price,
    this.variantId,
    this.barcodeValue,
    this.skuCode,
    this.productId,
    this.productName,
    this.productUnit,
    this.productSizeId,
    this.productSizeLabel,
    this.sizeLength,
    this.sizeWidth,
    this.colorId,
    this.colorName,
    this.orderId,
    this.orderDate,
  });

  /// Area in m² for this item.
  double get squareMeters =>
      (sizeLength != null && sizeWidth != null)
          ? sizeLength! * sizeWidth! * quantity / 10000.0
          : 0.0;

  /// Line total, unit-aware:
  ///  - piece: price × quantity
  ///  - m2:    price × sqm
  double get lineTotal => productUnit == 'piece'
      ? price * quantity
      : price * squareMeters;

  @override
  List<Object?> get props => [
        id,
        quantity,
        price,
        variantId,
        barcodeValue,
        skuCode,
        productId,
        productName,
        productUnit,
        productSizeId,
        productSizeLabel,
        sizeLength,
        sizeWidth,
        colorId,
        colorName,
        orderId,
        orderDate,
      ];
}
