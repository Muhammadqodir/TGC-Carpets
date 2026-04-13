import 'package:equatable/equatable.dart';

abstract class WarehouseFormEvent extends Equatable {
  const WarehouseFormEvent();

  @override
  List<Object?> get props => [];
}

class WarehouseFormSubmitted extends WarehouseFormEvent {
  final String type;
  final String documentDate;
  final List<Map<String, dynamic>> items;
  final String? sourceType;
  final int? sourceId;
  final String? notes;

  const WarehouseFormSubmitted({
    required this.type,
    required this.documentDate,
    required this.items,
    this.sourceType,
    this.sourceId,
    this.notes,
  });

  @override
  List<Object?> get props => [type, documentDate, items, sourceType, sourceId, notes];
}
