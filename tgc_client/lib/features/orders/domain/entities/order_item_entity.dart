import 'package:equatable/equatable.dart';

class OrderItemEntity extends Equatable {
  final int id;
  final int variantId;
  final String? variantSku;
  final String? variantBarcode;
  final int? productId;
  final String productName;
  final String? colorName;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final int quantity;

  const OrderItemEntity({
    required this.id,
    required this.variantId,
    this.variantSku,
    this.variantBarcode,
    required this.productId,
    required this.productName,
    this.colorName,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    required this.quantity,
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
        sizeLength,
        sizeWidth,
        productUnit,
        quantity,
      ];
}
