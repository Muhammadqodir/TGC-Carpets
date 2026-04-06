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
  final String color;
  final String unit;
  final String status;
  final String? imagePath;

  const ProductFormSubmitted({
    required this.name,
    this.productTypeId,
    this.productQualityId,
    required this.color,
    required this.unit,
    required this.status,
    this.imagePath,
  });

  @override
  List<Object?> get props => [
        name,
        productTypeId,
        productQualityId,
        color,
        unit,
        status,
        imagePath,
      ];
}

class ProductFormUpdateSubmitted extends ProductFormEvent {
  final int productId;
  final String name;
  final int? productTypeId;
  final int? productQualityId;
  final String color;
  final String unit;
  final String status;
  final String? imagePath;

  const ProductFormUpdateSubmitted({
    required this.productId,
    required this.name,
    this.productTypeId,
    this.productQualityId,
    required this.color,
    required this.unit,
    required this.status,
    this.imagePath,
  });

  @override
  List<Object?> get props => [
        productId,
        name,
        productTypeId,
        productQualityId,
        color,
        unit,
        status,
        imagePath,
      ];
}
