import 'package:equatable/equatable.dart';

class WarehouseDocumentItemEntity extends Equatable {
  final int id;
  final int productId;
  final String productName;
  final String? productSkuCode;
  final String? productUnit;
  final int quantity;
  final String? notes;

  const WarehouseDocumentItemEntity({
    required this.id,
    required this.productId,
    required this.productName,
    this.productSkuCode,
    this.productUnit,
    required this.quantity,
    this.notes,
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
        quantity,
        notes,
      ];
}
