import 'package:equatable/equatable.dart';

abstract class ClientFormEvent extends Equatable {
  const ClientFormEvent();

  @override
  List<Object?> get props => [];
}

class ClientFormSubmitted extends ClientFormEvent {
  final String contactName;
  final String phone;
  final String shopName;
  final String region;
  final String? address;
  final String? notes;

  const ClientFormSubmitted({
    required this.contactName,
    required this.phone,
    required this.shopName,
    required this.region,
    this.address,
    this.notes,
  });

  @override
  List<Object?> get props => [
        contactName,
        phone,
        shopName,
        region,
        address,
        notes,
      ];
}
