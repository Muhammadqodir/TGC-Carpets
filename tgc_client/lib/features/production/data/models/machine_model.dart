import '../../domain/entities/machine_entity.dart';

class MachineModel extends MachineEntity {
  const MachineModel({
    required super.id,
    required super.name,
    super.modelName,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      id: json['id'] as int,
      name: json['name'] as String,
      modelName: json['model_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model_name': modelName,
      };
}
