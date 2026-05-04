import 'package:equatable/equatable.dart';

abstract class ProductColorFormEvent extends Equatable {
  const ProductColorFormEvent();

  @override
  List<Object?> get props => [];
}

class ProductColorFormStarted extends ProductColorFormEvent {
  const ProductColorFormStarted();
}

class ProductColorFormSubmitted extends ProductColorFormEvent {
  final int productId;
  final int colorId;
  final String? imagePath;

  const ProductColorFormSubmitted({
    required this.productId,
    required this.colorId,
    this.imagePath,
  });

  @override
  List<Object?> get props => [productId, colorId, imagePath];
}

class ProductColorFormUpdated extends ProductColorFormEvent {
  final int productColorId;
  final int colorId;
  final String? imagePath;

  const ProductColorFormUpdated({
    required this.productColorId,
    required this.colorId,
    this.imagePath,
  });

  @override
  List<Object?> get props => [productColorId, colorId, imagePath];
}
