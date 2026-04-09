import 'package:equatable/equatable.dart';

import 'order_item_entity.dart';

class OrderEntity extends Equatable {
  final int id;
  final String uuid;
  final String? externalUuid;
  final int userId;
  final String userName;
  final int? clientId;
  final String? clientShopName;
  final String? clientPhone;
  final String status; // 'pending' | 'confirmed' | 'cancelled' | 'delivered'
  final DateTime orderDate;
  final String? notes;
  final List<OrderItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderEntity({
    required this.id,
    required this.uuid,
    this.externalUuid,
    required this.userId,
    required this.userName,
    this.clientId,
    this.clientShopName,
    this.clientPhone,
    required this.status,
    required this.orderDate,
    this.notes,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel => switch (status) {
        'pending'   => 'Kutilmoqda',
        'confirmed' => 'Tasdiqlangan',
        'cancelled' => 'Bekor qilindi',
        'delivered' => 'Yetkazildi',
        _           => status,
      };

  @override
  List<Object?> get props => [
        id,
        uuid,
        externalUuid,
        userId,
        userName,
        clientId,
        clientShopName,
        clientPhone,
        status,
        orderDate,
        notes,
        items,
        createdAt,
        updatedAt,
      ];
}
