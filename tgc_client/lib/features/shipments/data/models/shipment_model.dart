import '../../domain/entities/shipment_entity.dart';
import 'shipment_item_model.dart';

class ShipmentModel extends ShipmentEntity {
  const ShipmentModel({
    required super.id,
    required super.shipmentDatetime,
    super.notes,
    super.pdfUrl,
    super.invoiceUrl,
    super.clientId,
    super.clientShopName,
    super.clientRegion,
    super.userId,
    super.userName,
    required super.items,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    final clientMap = json['client'] as Map<String, dynamic>?;
    final userMap   = json['user']   as Map<String, dynamic>?;
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => ShipmentItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ShipmentModel(
      id:                json['id'] as int,
      shipmentDatetime:  DateTime.parse(json['shipment_datetime'] as String),
      notes:             json['notes'] as String?,
      pdfUrl:            json['pdf_url'] as String?,
      invoiceUrl:        json['invoice_url'] as String?,
      clientId:          clientMap?['id'] as int?,
      clientShopName:    clientMap?['shop_name'] as String?,
      clientRegion:      clientMap?['region'] as String?,
      userId:            userMap?['id'] as int?,
      userName:          userMap?['name'] as String?,
      items:             itemsList,
      createdAt:         DateTime.parse(json['created_at'] as String),
      updatedAt:         DateTime.parse(json['updated_at'] as String),
    );
  }
}
