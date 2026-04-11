import 'package:equatable/equatable.dart';

import 'production_batch_item_entity.dart';

class ProductionBatchEntity extends Equatable {
  final int id;
  final String batchTitle;
  final DateTime? plannedDatetime;
  final DateTime? startedDatetime;
  final DateTime? completedDatetime;
  final String type; // 'by_order' | 'for_stock' | 'mixed'
  final String status; // 'planned' | 'in_progress' | 'completed' | 'cancelled'
  final String? notes;
  final int? machineId;
  final String? machineName;
  final String? machineModelName;
  final int? createdById;
  final String? creatorName;
  final List<ProductionBatchItemEntity> items;
  final int? itemsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductionBatchEntity({
    required this.id,
    required this.batchTitle,
    this.plannedDatetime,
    this.startedDatetime,
    this.completedDatetime,
    required this.type,
    required this.status,
    this.notes,
    this.machineId,
    this.machineName,
    this.machineModelName,
    this.createdById,
    this.creatorName,
    required this.items,
    this.itemsCount,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel => switch (status) {
        'planned'     => 'Rejalashtirilgan',
        'in_progress' => 'Ishlab chiqarilmoqda',
        'completed'   => 'Yakunlangan',
        'cancelled'   => 'Bekor qilingan',
        _             => status,
      };

  String get typeLabel => switch (type) {
        'by_order'  => 'Buyurtma bo\'yicha',
        'for_stock' => 'Zaxira uchun',
        'mixed'     => 'Aralash',
        _           => type,
      };

  int get totalPlannedQuantity =>
      items.fold(0, (sum, i) => sum + i.plannedQuantity);

  int get totalProducedQuantity =>
      items.fold(0, (sum, i) => sum + i.producedQuantity);

  int get totalDefectQuantity =>
      items.fold(0, (sum, i) => sum + i.defectQuantity);

  int get effectiveItemsCount => itemsCount ?? items.length;

  @override
  List<Object?> get props => [
        id,
        batchTitle,
        plannedDatetime,
        startedDatetime,
        completedDatetime,
        type,
        status,
        notes,
        machineId,
        machineName,
        machineModelName,
        createdById,
        creatorName,
        items,
        itemsCount,
        createdAt,
        updatedAt,
      ];
}
