import '../../domain/entities/sale_entity.dart';
import 'sale_item_model.dart';

class SaleModel extends SaleEntity {
  const SaleModel({
    required super.id,
    required super.uuid,
    super.externalUuid,
    required super.saleDate,
    required super.totalAmount,
    super.notes,
    super.clientId,
    super.clientShopName,
    super.clientPhone,
    super.userId,
    super.userName,
    required super.items,
    required super.createdAt,
    required super.updatedAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    final clientMap = json['client'] as Map<String, dynamic>?;
    final userMap = json['user'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => SaleItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return SaleModel(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      externalUuid: json['external_uuid'] as String?,
      saleDate: DateTime.parse(json['sale_date'] as String),
      totalAmount: double.parse(json['total_amount'].toString()),
      notes: json['notes'] as String?,
      clientId: clientMap?['id'] as int?,
      clientShopName: clientMap?['shop_name'] as String?,
      clientPhone: clientMap?['phone'] as String?,
      userId: userMap?['id'] as int?,
      userName: userMap?['name'] as String?,
      items: itemsList,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
