import 'package:equatable/equatable.dart';

abstract class OrderFormEvent extends Equatable {
  const OrderFormEvent();

  @override
  List<Object?> get props => [];
}

class OrderFormSubmitted extends OrderFormEvent {
  final String orderDate;
  final List<Map<String, dynamic>> items;
  final int clientId;
  final String? notes;
  final String? externalUuid;

  const OrderFormSubmitted({
    required this.orderDate,
    required this.items,
    required this.clientId,
    this.notes,
    this.externalUuid,
  });

  @override
  List<Object?> get props => [orderDate, items, clientId, notes, externalUuid];
}

class OrderFormUpdateSubmitted extends OrderFormEvent {
  final int orderId;
  final String orderDate;
  final List<Map<String, dynamic>> items;
  final int clientId;
  final String? notes;

  const OrderFormUpdateSubmitted({
    required this.orderId,
    required this.orderDate,
    required this.items,
    required this.clientId,
    this.notes,
  });

  @override
  List<Object?> get props => [orderId, orderDate, items, clientId, notes];
}
