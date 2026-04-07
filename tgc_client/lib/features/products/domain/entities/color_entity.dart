import 'package:equatable/equatable.dart';

class ColorEntity extends Equatable {
  const ColorEntity({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
