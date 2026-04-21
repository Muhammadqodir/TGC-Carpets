import 'package:equatable/equatable.dart';

abstract class RawMaterialsEvent extends Equatable {
  const RawMaterialsEvent();

  @override
  List<Object?> get props => [];
}

class RawMaterialsLoadRequested extends RawMaterialsEvent {
  const RawMaterialsLoadRequested();
}

class RawMaterialsRefreshRequested extends RawMaterialsEvent {
  const RawMaterialsRefreshRequested();
}

class RawMaterialsNextPageRequested extends RawMaterialsEvent {
  const RawMaterialsNextPageRequested();
}

class RawMaterialsTypeFilterChanged extends RawMaterialsEvent {
  final String? type;

  const RawMaterialsTypeFilterChanged(this.type);

  @override
  List<Object?> get props => [type];
}

class RawMaterialsSearchChanged extends RawMaterialsEvent {
  final String query;

  const RawMaterialsSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class RawMaterialDeleteRequested extends RawMaterialsEvent {
  final int id;

  const RawMaterialDeleteRequested(this.id);

  @override
  List<Object?> get props => [id];
}
