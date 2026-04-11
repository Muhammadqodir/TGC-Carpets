import 'package:equatable/equatable.dart';

import 'production_batch_item_entity.dart';

class ProductionBatchMachine extends Equatable {
  final int id;
  final String name;
  final String? modelName;

  const ProductionBatchMachine({
    required this.id,
    required this.name,
    this.modelName,
  });

  @override
  List<Object?> get props => [id, name, modelName];
}

class ProductionBatchCreator extends Equatable {
  final int id;
  final String name;

  const ProductionBatchCreator({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

class ProductionBatchEntity extends Equatable {
  final int id;
  final String batchTitle;
  final String type; // 'by_order' | 'for_stock' | 'mixed'
  final String status; // 'planned' | 'in_progress' | 'completed' | 'cancelled'
  final DateTime? plannedDatetime;
  final DateTime? startedDatetime;
  final DateTime? completedDatetime;
  final String? notes;
  final ProductionBatchMachine? machine;
  final ProductionBatchCreator? creator;
  final ProductionBatchCreator? responsibleEmployee;
  final int itemsCount;
  final int totalPlannedQuantity;
  final double totalSqm;
  final List<ProductionBatchItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductionBatchEntity({
    required this.id,
    required this.batchTitle,
    required this.type,
    required this.status,
    this.plannedDatetime,
    this.startedDatetime,
    this.completedDatetime,
    this.notes,
    this.machine,
    this.creator,
    this.responsibleEmployee,
    required this.itemsCount,
    this.totalPlannedQuantity = 0,
    this.totalSqm = 0.0,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel => switch (status) {
        'planned'     => 'Rejalashtirilgan',
        'in_progress' => 'Ishlab chiqarilmoqda',
        'completed'   => 'Bajarildi',
        'cancelled'   => 'Bekor qilindi',
        _             => status,
      };

  String get typeLabel => switch (type) {
        'by_order'  => 'Buyurtma bo\'yicha',
        'for_stock' => 'Ombor uchun',
        'mixed'     => 'Aralash',
        _           => type,
      };

  @override
  List<Object?> get props => [
        id,
        batchTitle,
        type,
        status,
        plannedDatetime,
        startedDatetime,
        completedDatetime,
        notes,
        machine,
        creator,
        responsibleEmployee,
        itemsCount,
        totalPlannedQuantity,
        totalSqm,
        items,
        createdAt,
        updatedAt,
      ];
}
