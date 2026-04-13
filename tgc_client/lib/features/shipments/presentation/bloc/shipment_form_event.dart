import 'package:equatable/equatable.dart';

abstract class ShipmentFormEvent extends Equatable {
  const ShipmentFormEvent();

  @override
  List<Object?> get props => [];
}

class ShipmentFormSubmitted extends ShipmentFormEvent {
  final int clientId;
  final int? orderId;
  final String shipmentDatetime;
  final String? notes;
  final List<Map<String, dynamic>> items;

  const ShipmentFormSubmitted({
    required this.clientId,
    this.orderId,
    required this.shipmentDatetime,
    this.notes,
    required this.items,
  });

  @override
  List<Object?> get props =>
      [clientId, orderId, shipmentDatetime, notes, items];
}
