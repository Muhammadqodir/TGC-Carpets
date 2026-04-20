import 'package:equatable/equatable.dart';

class ClientEntity extends Equatable {
  final int id;
  final String uuid;
  final String? contactName;
  final String? phone;
  final String shopName;
  final String region;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientEntity({
    required this.id,
    required this.uuid,
    this.contactName,
    this.phone,
    required this.shopName,
    required this.region,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName =>
      contactName != null ? '$shopName ($contactName)' : shopName;

  @override
  List<Object?> get props => [
        id,
        uuid,
        contactName,
        phone,
        shopName,
        region,
        address,
        notes,
        createdAt,
        updatedAt,
      ];
}
