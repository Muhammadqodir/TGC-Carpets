import '../../domain/entities/client_debit_entity.dart';

class ClientDebitModel extends ClientDebitEntity {
  const ClientDebitModel({
    required super.id,
    required super.uuid,
    required super.contactName,
    required super.phone,
    required super.shopName,
    required super.region,
    required super.totalDebit,
    required super.totalCredit,
    required super.balance,
  });

  factory ClientDebitModel.fromJson(Map<String, dynamic> json) => ClientDebitModel(
        id:           json['id'] as int,
        uuid:         json['uuid'] as String,
        contactName:  json['contact_name'] as String,
        phone:        json['phone'] as String,
        shopName:     json['shop_name'] as String,
        region:       json['region'] as String,
        totalDebit:   (json['total_debit'] as num).toDouble(),
        totalCredit:  (json['total_credit'] as num).toDouble(),
        balance:      (json['balance'] as num).toDouble(),
      );
}
