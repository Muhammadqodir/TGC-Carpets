import 'package:equatable/equatable.dart';

class RawMaterialMovementEntity extends Equatable {
  final int id;
  final int materialId;
  final String? materialName;
  final String? materialType;
  final String? materialUnit;
  final int? userId;
  final String? userName;
  final DateTime dateTime;
  final String type; // 'received' | 'spent'
  final double quantity;
  final String? notes;

  const RawMaterialMovementEntity({
    required this.id,
    required this.materialId,
    this.materialName,
    this.materialType,
    this.materialUnit,
    this.userId,
    this.userName,
    required this.dateTime,
    required this.type,
    required this.quantity,
    this.notes,
  });

  @override
  List<Object?> get props => [id, materialId, dateTime, type, quantity];
}
