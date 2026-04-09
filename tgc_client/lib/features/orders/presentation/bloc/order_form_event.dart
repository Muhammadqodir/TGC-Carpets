import 'package:equatable/equatable.dart';

abstract class OrderFormEvent extends Equatable {
  const OrderFormEvent();

  @override
  List<Object?> get props => [];
}

class OrderFormSubmitted extends OrderFormEvent {
  final String orderDate;
  final List<Map<String, dynamic>> items;
  final int? clientId;
  final String status;
  final String? notes;
  final String? externalUuid;

  const OrderFormSubmitted({
    required this.orderDate,
    required this.items,
    this.clientId,
    this.status = 'pending',
    this.notes,
    this.externalUuid,
  });

  @override
  List<Object?> get props => [orderDate, items, clientId, status, notes, externalUuid];
}
