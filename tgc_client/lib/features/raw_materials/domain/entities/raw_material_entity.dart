import 'package:equatable/equatable.dart';

class RawMaterialEntity extends Equatable {
  final int id;
  final String name;
  final String type;
  final String unit; // 'piece' | 'sqm' | 'kg'
  final double stockQuantity;

  const RawMaterialEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.unit,
    required this.stockQuantity,
  });

  @override
  List<Object?> get props => [id, name, type, unit, stockQuantity];
}
