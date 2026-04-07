import 'package:equatable/equatable.dart';
import '../../domain/entities/color_entity.dart';
import '../../domain/entities/product_color_entity.dart';

abstract class ProductColorFormState extends Equatable {
  const ProductColorFormState();

  @override
  List<Object?> get props => [];
}

class ProductColorFormInitial extends ProductColorFormState {
  const ProductColorFormInitial();
}

class ProductColorFormLoading extends ProductColorFormState {
  const ProductColorFormLoading();
}

class ProductColorFormReady extends ProductColorFormState {
  final List<ColorEntity> colors;

  const ProductColorFormReady(this.colors);

  @override
  List<Object?> get props => [colors];
}

class ProductColorFormSubmitting extends ProductColorFormState {
  final List<ColorEntity> colors;

  const ProductColorFormSubmitting(this.colors);

  @override
  List<Object?> get props => [colors];
}

class ProductColorFormSuccess extends ProductColorFormState {
  final ProductColorEntity productColor;

  const ProductColorFormSuccess(this.productColor);

  @override
  List<Object?> get props => [productColor];
}

class ProductColorFormFailure extends ProductColorFormState {
  final String message;
  final List<ColorEntity> colors;

  const ProductColorFormFailure(this.message, {required this.colors});

  @override
  List<Object?> get props => [message, colors];
}
