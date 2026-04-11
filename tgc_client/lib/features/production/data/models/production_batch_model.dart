import '../../domain/entities/production_batch_entity.dart';

class ProductionBatchModel extends ProductionBatchEntity {
  const ProductionBatchModel({
    required super.id,
    required super.batchTitle,
    required super.type,
    required super.status,
    super.plannedDatetime,
    super.startedDatetime,
    super.completedDatetime,
    super.notes,
    super.machine,
    super.creator,
    required super.itemsCount,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductionBatchModel.fromJson(Map<String, dynamic> json) {
    final machineMap  = json['machine']  as Map<String, dynamic>?;
    final creatorMap  = json['creator']  as Map<String, dynamic>?;

    return ProductionBatchModel(
      id:                  json['id'] as int,
      batchTitle:          json['batch_title'] as String,
      type:                json['type'] as String,
      status:              json['status'] as String,
      plannedDatetime:     json['planned_datetime'] != null
          ? DateTime.parse(json['planned_datetime'] as String)
          : null,
      startedDatetime:     json['started_datetime'] != null
          ? DateTime.parse(json['started_datetime'] as String)
          : null,
      completedDatetime:   json['completed_datetime'] != null
          ? DateTime.parse(json['completed_datetime'] as String)
          : null,
      notes:               json['notes'] as String?,
      machine: machineMap != null
          ? ProductionBatchMachine(
              id:        machineMap['id'] as int,
              name:      machineMap['name'] as String,
              modelName: machineMap['model_name'] as String?,
            )
          : null,
      creator: creatorMap != null
          ? ProductionBatchCreator(
              id:   creatorMap['id'] as int,
              name: creatorMap['name'] as String,
            )
          : null,
      itemsCount: json['items_count'] as int? ?? 0,
      createdAt:  DateTime.parse(json['created_at'] as String),
      updatedAt:  DateTime.parse(json['updated_at'] as String),
    );
  }
}
