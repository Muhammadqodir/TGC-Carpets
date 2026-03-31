import 'package:equatable/equatable.dart';

abstract class SaleFormEvent extends Equatable {
  const SaleFormEvent();

  @override
  List<Object?> get props => [];
}

class SaleFormSubmitted extends SaleFormEvent {
  final int clientId;
  final String saleDate;
  final String paymentStatus;
  final List<Map<String, dynamic>> items;
  final String? notes;

  const SaleFormSubmitted({
    required this.clientId,
    required this.saleDate,
    required this.paymentStatus,
    required this.items,
    this.notes,
  });

  @override
  List<Object?> get props => [
        clientId,
        saleDate,
        paymentStatus,
        items,
        notes,
      ];
}
