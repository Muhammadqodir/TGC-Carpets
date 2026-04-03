import 'package:equatable/equatable.dart';
import 'sale_item_entity.dart';

class SaleEntity extends Equatable {
  final int id;
  final String uuid;
  final String? externalUuid;
  final DateTime saleDate;
  final double totalAmount;
  final String? notes;
  final int? clientId;
  final String? clientShopName;
  final String? clientPhone;
  final int? userId;
  final String? userName;
  final List<SaleItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SaleEntity({
    required this.id,
    required this.uuid,
    this.externalUuid,
    required this.saleDate,
    required this.totalAmount,
    this.notes,
    this.clientId,
    this.clientShopName,
    this.clientPhone,
    this.userId,
    this.userName,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        uuid,
        externalUuid,
        saleDate,
        totalAmount,
        notes,
        clientId,
        clientShopName,
        clientPhone,
        userId,
        userName,
        items,
        createdAt,
        updatedAt,
      ];
}
