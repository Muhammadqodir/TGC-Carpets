import 'package:equatable/equatable.dart';

abstract class RawMaterialFormEvent extends Equatable {
  const RawMaterialFormEvent();

  @override
  List<Object?> get props => [];
}

class RawMaterialFormSubmitted extends RawMaterialFormEvent {
  final String name;
  final String type;
  final String unit;

  const RawMaterialFormSubmitted({
    required this.name,
    required this.type,
    required this.unit,
  });

  @override
  List<Object?> get props => [name, type, unit];
}
