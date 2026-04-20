import 'package:equatable/equatable.dart';

abstract class ClientFormEvent extends Equatable {
  const ClientFormEvent();

  @override
  List<Object?> get props => [];
}

class ClientFormSubmitted extends ClientFormEvent {
  final String? contactName;
  final String? phone;
  final String shopName;
  final String region;
  final String? address;
  final String? notes;

  const ClientFormSubmitted({
    this.contactName,
    this.phone,
    required this.shopName,
    required this.region,
    this.address,
    this.notes,
  });

  @override
  List<Object?> get props => [contactName, phone, shopName, region, address, notes];
}

class ClientFormUpdateSubmitted extends ClientFormEvent {
  final int clientId;
  final String? contactName;
  final String? phone;
  final String shopName;
  final String region;
  final String? address;
  final String? notes;

  const ClientFormUpdateSubmitted({
    required this.clientId,
    this.contactName,
    this.phone,
    required this.shopName,
    required this.region,
    this.address,
    this.notes,
  });

  @override
  List<Object?> get props =>
      [clientId, contactName, phone, shopName, region, address, notes];
}
