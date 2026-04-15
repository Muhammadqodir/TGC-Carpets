import 'package:equatable/equatable.dart';

abstract class PaymentFormEvent extends Equatable {
  const PaymentFormEvent();

  @override
  List<Object?> get props => [];
}

class PaymentFormSubmitted extends PaymentFormEvent {
  final int clientId;
  final int? orderId;
  final double amount;
  final String? notes;

  const PaymentFormSubmitted({
    required this.clientId,
    this.orderId,
    required this.amount,
    this.notes,
  });

  @override
  List<Object?> get props => [clientId, orderId, amount, notes];
}
