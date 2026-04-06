import 'package:equatable/equatable.dart';
import '../../domain/entities/product_entity.dart';
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

  const ProductFormReady(this.productTypes);

  @override
  List<Object?> get props => [productTypes];
}

class ProductFormSubmitting extends ProductFormState {
  final List<ProductTypeEntity> productTypes;

  const ProductFormSubmitting(this.productTypes);

  @override
  List<Object?> get props => [productTypes];
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

  const ProductFormFailure(this.message, {this.productTypes = const []});

  @override
  List<Object?> get props => [message, productTypes];
}
