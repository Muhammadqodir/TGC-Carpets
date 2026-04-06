import 'package:equatable/equatable.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';

abstract class ProductFormState extends Equatable {
  const ProductFormState();

  @override
  List<Object?> get props => [];
}

class ProductFormInitial extends ProductFormState {
  const ProductFormInitial();
}

class ProductFormTypesLoading extends ProductFormState {
  const ProductFormTypesLoading();
}

class ProductFormReady extends ProductFormState {
  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;

  const ProductFormReady(this.productTypes, {this.productQualities = const []});

  @override
  List<Object?> get props => [productTypes, productQualities];
}

class ProductFormSubmitting extends ProductFormState {
  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;

  const ProductFormSubmitting(this.productTypes, {this.productQualities = const []});

  @override
  List<Object?> get props => [productTypes, productQualities];
}

class ProductFormSuccess extends ProductFormState {
  final ProductEntity product;

  const ProductFormSuccess(this.product);

  @override
  List<Object?> get props => [product];
}

class ProductFormFailure extends ProductFormState {
  final String message;
  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;

  const ProductFormFailure(
    this.message, {
    this.productTypes = const [],
    this.productQualities = const [],
  });

  @override
  List<Object?> get props => [message, productTypes, productQualities];
}
