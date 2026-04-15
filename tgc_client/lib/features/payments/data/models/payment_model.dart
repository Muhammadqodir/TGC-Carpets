import '../../domain/entities/payment_entity.dart';

class PaymentModel extends PaymentEntity {
  const PaymentModel({
    required super.id,
    required super.amount,
    super.notes,
    super.clientId,
    super.clientShopName,
    super.clientRegion,
    super.userId,
    super.userName,
    super.orderId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final clientMap = json['client'] as Map<String, dynamic>?;
    final userMap   = json['user']   as Map<String, dynamic>?;
    final orderMap  = json['order']  as Map<String, dynamic>?;

    return PaymentModel(
      id:              json['id'] as int,
      amount:          (json['amount'] as num).toDouble(),
      notes:           json['notes'] as String?,
      clientId:        clientMap?['id'] as int?,
      clientShopName:  clientMap?['shop_name'] as String?,
      clientRegion:    clientMap?['region'] as String?,
      userId:          userMap?['id'] as int?,
      userName:        userMap?['name'] as String?,
      orderId:         orderMap?['id'] as int?,
      createdAt:       DateTime.parse(json['created_at'] as String),
      updatedAt:       DateTime.parse(json['updated_at'] as String),
    );
  }
}
