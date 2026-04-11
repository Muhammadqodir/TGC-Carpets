import 'package:equatable/equatable.dart';

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
  final int itemsCount;
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
    required this.itemsCount,
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
        itemsCount,
        createdAt,
        updatedAt,
      ];
}
