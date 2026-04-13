import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_shipment_usecase.dart';
import 'shipment_form_event.dart';
import 'shipment_form_state.dart';

class ShipmentFormBloc extends Bloc<ShipmentFormEvent, ShipmentFormState> {
  final CreateShipmentUseCase createShipmentUseCase;

  ShipmentFormBloc({required this.createShipmentUseCase})
      : super(const ShipmentFormInitial()) {
    on<ShipmentFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    ShipmentFormSubmitted event,
    Emitter<ShipmentFormState> emit,
  ) async {
    emit(const ShipmentFormSubmitting());

    final result = await createShipmentUseCase(
      clientId: event.clientId,
      orderId: event.orderId,
      shipmentDatetime: event.shipmentDatetime,
      notes: event.notes,
      items: event.items,
    );

    result.fold(
      (failure) => emit(ShipmentFormFailure(failure.message)),
      (shipment) => emit(ShipmentFormSuccess(shipment)),
    );
  }
}
