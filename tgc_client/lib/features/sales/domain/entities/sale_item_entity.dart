import 'package:equatable/equatable.dart';

class SaleItemEntity extends Equatable {
  final int id;
  final int productId;
  final String productName;
  final String? productSkuCode;
  final String productUnit;
  final int? productSizeId;
  final String? productSizeLabel;
  final int quantity;
  final double price;
  final double subtotal;

  const SaleItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSkuCode,
    required this.productUnit,
    this.productSizeId,
    this.productSizeLabel,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        productSkuCode,
        productUnit,
        productSizeId,
        productSizeLabel,
        quantity,
        price,
        subtotal,
      ];
}
