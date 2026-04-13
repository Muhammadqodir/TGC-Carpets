import 'package:equatable/equatable.dart';

class ShipmentItemEntity extends Equatable {
  final int id;
  final int quantity;
  final double price;
  final double total;
  final int? variantId;
  final String? barcodeValue;
  final String? skuCode;
  final int? productId;
  final String? productName;
  final String? productUnit; // 'piece' | 'm2'
  final int? productSizeId;
  final String? productSizeLabel;
  final int? colorId;
  final String? colorName;

  const ShipmentItemEntity({
    required this.id,
    required this.quantity,
    required this.price,
    required this.total,
    this.variantId,
    this.barcodeValue,
    this.skuCode,
    this.productId,
    this.productName,
    this.productUnit,
    this.productSizeId,
    this.productSizeLabel,
    this.colorId,
    this.colorName,
  });

  /// Area in m² for this item (0 if unit is piece).
  double get squareMeters =>
      productUnit == 'm2' ? quantity.toDouble() : 0.0;

  @override
  List<Object?> get props => [
        id,
        quantity,
        price,
        total,
        variantId,
        barcodeValue,
        skuCode,
        productId,
        productName,
        productUnit,
        productSizeId,
        productSizeLabel,
        colorId,
        colorName,
      ];
}
