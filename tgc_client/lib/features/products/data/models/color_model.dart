import '../../domain/entities/color_entity.dart';

class ColorModel extends ColorEntity {
  const ColorModel({required super.id, required super.name});

  factory ColorModel.fromJson(Map<String, dynamic> json) {
    return ColorModel(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
