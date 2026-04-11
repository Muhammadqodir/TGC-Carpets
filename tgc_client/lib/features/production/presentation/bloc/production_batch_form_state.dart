import 'package:equatable/equatable.dart';

import '../../domain/entities/production_batch_entity.dart';

abstract class ProductionBatchFormState extends Equatable {
  const ProductionBatchFormState();

  @override
  List<Object?> get props => [];
}

class ProductionBatchFormInitial extends ProductionBatchFormState {
  const ProductionBatchFormInitial();
}

class ProductionBatchFormSubmitting extends ProductionBatchFormState {
  const ProductionBatchFormSubmitting();
}

class ProductionBatchFormSuccess extends ProductionBatchFormState {
  final ProductionBatchEntity batch;

  const ProductionBatchFormSuccess(this.batch);

  @override
  List<Object?> get props => [batch];
}

class ProductionBatchFormFailure extends ProductionBatchFormState {
  final String message;

  const ProductionBatchFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
