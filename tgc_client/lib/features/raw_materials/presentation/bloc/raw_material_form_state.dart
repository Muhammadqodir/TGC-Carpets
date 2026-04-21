import 'package:equatable/equatable.dart';

import '../../domain/entities/raw_material_entity.dart';

abstract class RawMaterialFormState extends Equatable {
  const RawMaterialFormState();

  @override
  List<Object?> get props => [];
}

class RawMaterialFormInitial extends RawMaterialFormState {
  const RawMaterialFormInitial();
}

class RawMaterialFormLoading extends RawMaterialFormState {
  const RawMaterialFormLoading();
}

class RawMaterialFormSuccess extends RawMaterialFormState {
  final RawMaterialEntity material;

  const RawMaterialFormSuccess(this.material);

  @override
  List<Object?> get props => [material];
}

class RawMaterialFormError extends RawMaterialFormState {
  final String message;

  const RawMaterialFormError(this.message);

  @override
  List<Object?> get props => [message];
}
