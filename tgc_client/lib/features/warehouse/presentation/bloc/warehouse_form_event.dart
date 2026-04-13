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
  final String? notes;

  const WarehouseFormSubmitted({
    required this.type,
    required this.documentDate,
    required this.items,
    this.notes,
  });

  @override
  List<Object?> get props => [type, documentDate, items, notes];
}
