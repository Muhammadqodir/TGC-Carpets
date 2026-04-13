import 'package:equatable/equatable.dart';

class WarehouseDocumentItemEntity extends Equatable {
  final int id;
  final int productId;
  final String productName;
  final String? productSkuCode;
  final String? productUnit;
  final int? productSizeId;
  final String? productSizeLabel;
  final int? colorId;
  final String? colorName;
  final int quantity;
  final String? notes;
  final int? variantId;
  final String? barcodeValue;

  const WarehouseDocumentItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSkuCode,
    this.productUnit,
    this.productSizeId,
    this.productSizeLabel,
    this.colorId,
    this.colorName,
    required this.quantity,
    this.notes,
    this.variantId,
    this.barcodeValue,
  });

  String? get unitLabel => switch (productUnit) {
        'piece' => 'dona',
        'm2' => 'm²',
        _ => productUnit,
      };

  @override
  List<Object?> get props => [
        id,
        productId,
        productName,
        productSkuCode,
        productUnit,
        productSizeId,
        productSizeLabel,
        colorId,
        colorName,
        quantity,
        notes,
        variantId,
        barcodeValue,
      ];
}
