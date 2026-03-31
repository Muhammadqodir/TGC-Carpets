import 'package:equatable/equatable.dart';

import '../../domain/entities/warehouse_document_entity.dart';

abstract class WarehouseFormState extends Equatable {
  const WarehouseFormState();

  @override
  List<Object?> get props => [];
}

class WarehouseFormInitial extends WarehouseFormState {
  const WarehouseFormInitial();
}

class WarehouseFormSubmitting extends WarehouseFormState {
  const WarehouseFormSubmitting();
}

class WarehouseFormSuccess extends WarehouseFormState {
  final WarehouseDocumentEntity document;

  const WarehouseFormSuccess(this.document);

  @override
  List<Object?> get props => [document];
}

class WarehouseFormFailure extends WarehouseFormState {
  final String message;

  const WarehouseFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
