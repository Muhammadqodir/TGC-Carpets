import 'package:equatable/equatable.dart';

class PaymentEntity extends Equatable {
  final int id;
  final double amount;
  final String? notes;
  final int? clientId;
  final String? clientShopName;
  final String? clientRegion;
  final int? userId;
  final String? userName;
  final int? orderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentEntity({
    required this.id,
    required this.amount,
    this.notes,
    this.clientId,
    this.clientShopName,
    this.clientRegion,
    this.userId,
    this.userName,
    this.orderId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        amount,
        notes,
        clientId,
        clientShopName,
        clientRegion,
        userId,
        userName,
        orderId,
        createdAt,
        updatedAt,
      ];
}
