import '../../domain/entities/client_entity.dart';

class ClientModel extends ClientEntity {
  const ClientModel({
    required super.id,
    required super.uuid,
    super.contactName,
    super.phone,
    required super.shopName,
    required super.region,
    super.address,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
        id: json['id'] as int,
        uuid: json['uuid'] as String,
        contactName: json['contact_name'] as String?,
        phone: json['phone'] as String?,
        shopName: json['shop_name'] as String,
        region: json['region'] as String,
        address: json['address'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'contact_name': contactName,
        'phone': phone,
        'shop_name': shopName,
        'region': region,
        'address': address,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
