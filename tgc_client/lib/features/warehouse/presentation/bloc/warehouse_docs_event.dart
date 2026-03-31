import 'package:equatable/equatable.dart';

abstract class WarehouseDocsEvent extends Equatable {
  const WarehouseDocsEvent();

  @override
  List<Object?> get props => [];
}

class WarehouseDocsLoadRequested extends WarehouseDocsEvent {
  const WarehouseDocsLoadRequested();
}

class WarehouseDocsTypeFilterChanged extends WarehouseDocsEvent {
  final String? type; // null = all

  const WarehouseDocsTypeFilterChanged(this.type);

  @override
  List<Object?> get props => [type];
}

class WarehouseDocsNextPageRequested extends WarehouseDocsEvent {
  const WarehouseDocsNextPageRequested();
}

class WarehouseDocsRefreshRequested extends WarehouseDocsEvent {
  const WarehouseDocsRefreshRequested();
}
