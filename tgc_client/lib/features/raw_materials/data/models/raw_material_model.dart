import '../../domain/entities/raw_material_entity.dart';

class RawMaterialModel extends RawMaterialEntity {
  const RawMaterialModel({
    required super.id,
    required super.name,
    required super.type,
    required super.unit,
    required super.stockQuantity,
  });

  factory RawMaterialModel.fromJson(Map<String, dynamic> json) =>
      RawMaterialModel(
        id:            json['id'] as int,
        name:          json['name'] as String,
        type:          json['type'] as String,
        unit:          json['unit'] as String,
        stockQuantity: (json['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      );
}
