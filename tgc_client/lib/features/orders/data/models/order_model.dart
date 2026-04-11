import '../../domain/entities/order_entity.dart';
import 'order_item_model.dart';

class OrderModel extends OrderEntity {
  const OrderModel({
    required super.id,
    required super.uuid,
    super.externalUuid,
    required super.userId,
    required super.userName,
    super.clientId,
    super.clientShopName,
    super.clientPhone,
    super.clientRegion,
    required super.status,
    required super.orderDate,
    super.notes,
    required super.items,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final userMap   = json['user']   as Map<String, dynamic>?;
    final clientMap = json['client'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return OrderModel(
      id:             json['id'] as int,
      uuid:           json['uuid'] as String,
      externalUuid:   json['external_uuid'] as String?,
      userId:         userMap?['id'] as int? ?? 0,
      userName:       userMap?['name'] as String? ?? '',
      clientId:       clientMap?['id'] as int?,
      clientShopName: clientMap?['shop_name'] as String?,
      clientPhone:    clientMap?['phone'] as String?,
      clientRegion:   clientMap?['region'] as String?,
      status:         json['status'] as String,
      orderDate:      DateTime.parse(json['order_date'] as String),
      notes:          json['notes'] as String?,
      items:          itemsList,
      createdAt:      DateTime.parse(json['created_at'] as String),
      updatedAt:      DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':             id,
        'uuid':           uuid,
        'external_uuid':  externalUuid,
        'user':           {'id': userId, 'name': userName},
        'client':         clientId != null
            ? {'id': clientId, 'shop_name': clientShopName}
            : null,
        'status':         status,
        'order_date':     orderDate.toIso8601String(),
        'notes':          notes,
        'items':          items
            .cast<OrderItemModel>()
            .map((e) => e.toJson())
            .toList(),
        'created_at':     createdAt.toIso8601String(),
        'updated_at':     updatedAt.toIso8601String(),
      };
}
