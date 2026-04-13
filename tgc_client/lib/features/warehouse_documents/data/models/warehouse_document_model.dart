import '../../domain/entities/warehouse_document_entity.dart';
import 'warehouse_document_item_model.dart';

class WarehouseDocumentModel extends WarehouseDocumentEntity {
  const WarehouseDocumentModel({
    required super.id,
    required super.uuid,
    super.externalUuid,
    required super.type,
    required super.documentDate,
    super.notes,
    required super.userId,
    required super.userName,
    required super.items,
    super.pdfUrl,
    required super.createdAt,
    required super.updatedAt,
  });

  factory WarehouseDocumentModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List? ?? [])
        .map((e) => WarehouseDocumentItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return WarehouseDocumentModel(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      externalUuid: json['external_uuid'] as String?,
      type: json['type'] as String,
      documentDate: DateTime.parse(json['document_date'] as String),
      notes: json['notes'] as String?,
      userId: userMap?['id'] as int? ?? 0,
      userName: userMap?['name'] as String? ?? '',
      items: itemsList,
      pdfUrl: json['pdf_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'external_uuid': externalUuid,
        'type': type,
        'document_date': documentDate.toIso8601String(),
        'notes': notes,
        'user': {'id': userId, 'name': userName},
        'items': items
            .cast<WarehouseDocumentItemModel>()
            .map((e) => e.toJson())
            .toList(),
        'pdf_url': pdfUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
