import '../../domain/entities/production_batch_entity.dart';

/// Simple data model for a machine, extends [ProductionBatchMachine] so it
/// can be used directly wherever the entity is expected.
class MachineModel extends ProductionBatchMachine {
  const MachineModel({
    required super.id,
    required super.name,
    super.modelName,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      id:        json['id'] as int,
      name:      json['name'] as String,
      modelName: json['model_name'] as String?,
    );
  }
}
