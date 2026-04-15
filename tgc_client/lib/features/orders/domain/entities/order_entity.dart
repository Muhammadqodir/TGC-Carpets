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
  final String? clientRegion;
  final String status; // 'pending' | 'on_production' | 'done' | 'canceled'
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
    this.clientRegion,
    required this.status,
    required this.orderDate,
    this.notes,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel => switch (status) {
        'pending'       => 'Kutilmoqda',
        'planned'       => 'Rejalashtirilgan',
        'on_production' => 'Ishlab chiqarilmoqda',
        'done'          => 'Bajarildi',
        'canceled'      => 'Bekor qilindi',
        _               => status,
      };

  /// Sum of quantities across all line items.
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  /// Sum of planned quantities across all line items.
  int get totalPlannedQuantity =>
      items.fold(0, (sum, i) => sum + (i.plannedQuantity ?? 0));

  /// Sum of actually produced quantities across all line items (production progress numerator).
  int get totalProducedQuantity =>
      items.fold(0, (sum, i) => sum + (i.producedQuantity ?? 0));

  /// Sum of warehouse-received quantities across all line items.
  int get totalWarehouseReceivedQuantity =>
      items.fold(0, (sum, i) => sum + (i.warehouseReceivedQuantity ?? 0));

  /// Production progress: produced / ordered (0.0 – 1.0). Returns 0 when totalQuantity is 0.
  double get productionProgress =>
      totalQuantity == 0 ? 0.0 : (totalProducedQuantity / totalQuantity).clamp(0.0, 1.0);

  /// Total square metres: Σ(length × width × quantity) / 10 000.
  /// Items without a size contribute 0.
  double get totalSqm => items.fold(0.0, (sum, i) {
        if (i.sizeLength == null || i.sizeWidth == null) return sum;
        return sum + i.sizeLength! * i.sizeWidth! * i.quantity / 10000.0;
      });

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
        clientRegion,
        status,
        orderDate,
        notes,
        items,
        createdAt,
        updatedAt,
      ];
}
