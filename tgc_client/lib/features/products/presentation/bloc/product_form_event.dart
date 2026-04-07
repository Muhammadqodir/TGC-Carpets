import 'package:equatable/equatable.dart';

abstract class ProductFormEvent extends Equatable {
  const ProductFormEvent();

  @override
  List<Object?> get props => [];
}

class ProductFormStarted extends ProductFormEvent {
  const ProductFormStarted();
}

class ProductFormSubmitted extends ProductFormEvent {
  final String name;
  final int? productTypeId;
  final int? productQualityId;
  final String unit;
  final String status;

  const ProductFormSubmitted({
    required this.name,
    this.productTypeId,
    this.productQualityId,
    required this.unit,
    required this.status,
  });

  @override
  List<Object?> get props => [
        name,
        productTypeId,
        productQualityId,
        unit,
        status,
      ];
}

class ProductFormUpdateSubmitted extends ProductFormEvent {
  final int productId;
  final String name;
  final int? productTypeId;
  final int? productQualityId;
  final String unit;
  final String status;

  const ProductFormUpdateSubmitted({
    required this.productId,
    required this.name,
    this.productTypeId,
    this.productQualityId,
    required this.unit,
    required this.status,
  });

  @override
  List<Object?> get props => [
        productId,
        name,
        productTypeId,
        productQualityId,
        unit,
        status,
      ];
}
