import 'package:equatable/equatable.dart';

abstract class ProductFormEvent extends Equatable {
  const ProductFormEvent();

  @override
  List<Object?> get props => [];
}

class ProductFormSubmitted extends ProductFormEvent {
  final String name;
  final String length;
  final String width;
  final String quality;
  final String density;
  final String color;
  final String? edge;
  final String unit;
  final String status;
  final String? imagePath;

  const ProductFormSubmitted({
    required this.name,
    required this.length,
    required this.width,
    required this.quality,
    required this.density,
    required this.color,
    this.edge,
    required this.unit,
    required this.status,
    this.imagePath,
  });

  @override
  List<Object?> get props => [
        name,
        length,
        width,
        quality,
        density,
        color,
        edge,
        unit,
        status,
        imagePath,
      ];
}
