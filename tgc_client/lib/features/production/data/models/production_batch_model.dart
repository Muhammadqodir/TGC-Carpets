import '../../domain/entities/production_batch_entity.dart';
import 'production_batch_item_model.dart';

class ProductionBatchModel extends ProductionBatchEntity {
  const ProductionBatchModel({
    required super.id,
    required super.batchTitle,
    super.plannedDatetime,
    super.startedDatetime,
    super.completedDatetime,
    required super.type,
    required super.status,
    super.notes,
    super.machineId,
    super.machineName,
    super.machineModelName,
    super.createdById,
    super.creatorName,
    required super.items,
    super.itemsCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductionBatchModel.fromJson(Map<String, dynamic> json) {
    final machineMap = json['machine'] as Map<String, dynamic>?;
    final creatorMap = json['creator'] as Map<String, dynamic>?;
    final itemsList = (json['items'] as List? ?? [])
        .map((e) =>
            ProductionBatchItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ProductionBatchModel(
      id: json['id'] as int,
      batchTitle: json['batch_title'] as String,
      plannedDatetime: json['planned_datetime'] != null
          ? DateTime.parse(json['planned_datetime'] as String)
          : null,
      startedDatetime: json['started_datetime'] != null
          ? DateTime.parse(json['started_datetime'] as String)
          : null,
      completedDatetime: json['completed_datetime'] != null
          ? DateTime.parse(json['completed_datetime'] as String)
          : null,
      type: json['type'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      machineId: machineMap?['id'] as int?,
      machineName: machineMap?['name'] as String?,
      machineModelName: machineMap?['model_name'] as String?,
      createdById: creatorMap?['id'] as int?,
      creatorName: creatorMap?['name'] as String?,
      items: itemsList,
      itemsCount: json['items_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
