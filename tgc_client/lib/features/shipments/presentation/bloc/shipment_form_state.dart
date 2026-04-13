import 'package:equatable/equatable.dart';

import '../../domain/entities/shipment_entity.dart';

abstract class ShipmentFormState extends Equatable {
  const ShipmentFormState();

  @override
  List<Object?> get props => [];
}

class ShipmentFormInitial extends ShipmentFormState {
  const ShipmentFormInitial();
}

class ShipmentFormSubmitting extends ShipmentFormState {
  const ShipmentFormSubmitting();
}

class ShipmentFormSuccess extends ShipmentFormState {
  final ShipmentEntity shipment;
  const ShipmentFormSuccess(this.shipment);

  @override
  List<Object?> get props => [shipment];
}

class ShipmentFormFailure extends ShipmentFormState {
  final String message;
  const ShipmentFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
