import '../../domain/entities/raw_material_movement_entity.dart';

class RawMaterialMovementModel extends RawMaterialMovementEntity {
  const RawMaterialMovementModel({
    required super.id,
    required super.materialId,
    super.materialName,
    super.materialType,
    super.materialUnit,
    super.userId,
    super.userName,
    required super.dateTime,
    required super.type,
    required super.quantity,
    super.notes,
  });

  factory RawMaterialMovementModel.fromJson(Map<String, dynamic> json) {
    final material = json['material'] as Map<String, dynamic>?;
    final user     = json['user']     as Map<String, dynamic>?;

    return RawMaterialMovementModel(
      id:           json['id'] as int,
      materialId:   json['material_id'] as int,
      materialName: material?['name'] as String?,
      materialType: material?['type'] as String?,
      materialUnit: material?['unit'] as String?,
      userId:       user?['id'] as int?,
      userName:     user?['name'] as String?,
      dateTime:     DateTime.parse(json['date_time'] as String),
      type:         json['type'] as String,
      quantity:     (json['quantity'] as num).toDouble(),
      notes:        json['notes'] as String?,
    );
  }
}
