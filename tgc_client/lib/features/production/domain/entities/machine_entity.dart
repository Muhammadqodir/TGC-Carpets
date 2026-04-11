import 'package:equatable/equatable.dart';

class MachineEntity extends Equatable {
  final int id;
  final String name;
  final String? modelName;

  const MachineEntity({
    required this.id,
    required this.name,
    this.modelName,
  });

  String get displayName => modelName != null ? '$name ($modelName)' : name;

  @override
  List<Object?> get props => [id, name, modelName];
}
