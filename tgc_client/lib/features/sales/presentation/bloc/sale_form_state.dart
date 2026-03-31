import 'package:equatable/equatable.dart';
import '../../domain/entities/sale_entity.dart';

abstract class SaleFormState extends Equatable {
  const SaleFormState();

  @override
  List<Object?> get props => [];
}

class SaleFormInitial extends SaleFormState {
  const SaleFormInitial();
}

class SaleFormSubmitting extends SaleFormState {
  const SaleFormSubmitting();
}

class SaleFormSuccess extends SaleFormState {
  final SaleEntity sale;

  const SaleFormSuccess(this.sale);

  @override
  List<Object?> get props => [sale];
}

class SaleFormFailure extends SaleFormState {
  final String message;

  const SaleFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
