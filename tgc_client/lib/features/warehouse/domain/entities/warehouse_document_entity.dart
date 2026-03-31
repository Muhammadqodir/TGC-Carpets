import 'package:equatable/equatable.dart';

import 'warehouse_document_item_entity.dart';

class WarehouseDocumentEntity extends Equatable {
  final int id;
  final String uuid;
  final String? externalUuid;
  final String type; // 'in' | 'out' | 'adjustment' | 'return'
  final DateTime documentDate;
  final String? notes;
  final int userId;
  final String userName;
  final int? clientId;
  final String? clientShopName;
  final List<WarehouseDocumentItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WarehouseDocumentEntity({
    required this.id,
    required this.uuid,
    this.externalUuid,
    required this.type,
    required this.documentDate,
    this.notes,
    required this.userId,
    required this.userName,
    this.clientId,
    this.clientShopName,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  String get typeLabel => switch (type) {
        'in' => 'Kirim',
        'out' => 'Chiqim',
        'return' => 'Qaytish',
        _ => type,
      };

  @override
  List<Object?> get props => [
        id,
        uuid,
        externalUuid,
        type,
        documentDate,
        notes,
        userId,
        userName,
        clientId,
        clientShopName,
        items,
        createdAt,
        updatedAt,
      ];
}
