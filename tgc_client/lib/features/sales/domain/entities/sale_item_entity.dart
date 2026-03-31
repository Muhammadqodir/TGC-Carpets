import 'package:equatable/equatable.dart';

class SaleItemEntity extends Equatable {
  final int id;
  final int productId;
  final String productName;
  final String? productSkuCode;
  final String productUnit;
  final int quantity;
  final double price;
  final double subtotal;

  const SaleItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSkuCode,
    required this.productUnit,
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
        quantity,
        price,
        subtotal,
      ];
}
