import 'package:equatable/equatable.dart';

abstract class ProductionBatchFormEvent extends Equatable {
  const ProductionBatchFormEvent();

  @override
  List<Object?> get props => [];
}

class ProductionBatchFormSubmitted extends ProductionBatchFormEvent {
  final String batchTitle;
  final int machineId;
  final String? plannedDatetime;
  final String? type;
  final String? notes;
  final List<Map<String, dynamic>>? items;

  const ProductionBatchFormSubmitted({
    required this.batchTitle,
    required this.machineId,
    this.plannedDatetime,
    this.type,
    this.notes,
    this.items,
  });

  @override
  List<Object?> get props =>
      [batchTitle, machineId, plannedDatetime, type, notes, items];
}

class ProductionBatchFormUpdateSubmitted extends ProductionBatchFormEvent {
  final int batchId;
  final String batchTitle;
  final int machineId;
  final String? plannedDatetime;
  final String? type;
  final String? notes;
  final List<Map<String, dynamic>>? items;

  const ProductionBatchFormUpdateSubmitted({
    required this.batchId,
    required this.batchTitle,
    required this.machineId,
    this.plannedDatetime,
    this.type,
    this.notes,
    this.items,
  });

  @override
  List<Object?> get props =>
      [batchId, batchTitle, machineId, plannedDatetime, type, notes, items];
}
