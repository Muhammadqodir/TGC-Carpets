import 'package:equatable/equatable.dart';

class StockVariantEntity extends Equatable {
  final int id;
  final String productName;
  final String colorName;
  final String? imageUrl;
  final String? qualityName;
  final String? typeName;
  final String? size;
  final int quantityReserved;
  final int quantityWarehouse;

  const StockVariantEntity({
    required this.id,
    required this.productName,
    required this.colorName,
    this.imageUrl,
    this.qualityName,
    this.typeName,
    this.size,
    required this.quantityReserved,
    required this.quantityWarehouse,
  });

  @override
  List<Object?> get props => [
        id,
        productName,
        colorName,
        imageUrl,
        qualityName,
        typeName,
        size,
        quantityReserved,
        quantityWarehouse,
      ];
}
