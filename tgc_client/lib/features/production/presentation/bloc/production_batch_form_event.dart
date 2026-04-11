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

class ProductionBatchStartRequested extends ProductionBatchFormEvent {
  final int batchId;

  const ProductionBatchStartRequested(this.batchId);

  @override
  List<Object?> get props => [batchId];
}

class ProductionBatchCompleteRequested extends ProductionBatchFormEvent {
  final int batchId;

  const ProductionBatchCompleteRequested(this.batchId);

  @override
  List<Object?> get props => [batchId];
}

class ProductionBatchCancelRequested extends ProductionBatchFormEvent {
  final int batchId;

  const ProductionBatchCancelRequested(this.batchId);

  @override
  List<Object?> get props => [batchId];
}

class ProductionBatchItemUpdateRequested extends ProductionBatchFormEvent {
  final int batchId;
  final int itemId;
  final int? producedQuantity;
  final int? defectQuantity;
  final String? notes;

  const ProductionBatchItemUpdateRequested({
    required this.batchId,
    required this.itemId,
    this.producedQuantity,
    this.defectQuantity,
    this.notes,
  });

  @override
  List<Object?> get props =>
      [batchId, itemId, producedQuantity, defectQuantity, notes];
}

class ProductionBatchLoadRequested extends ProductionBatchFormEvent {
  final int batchId;

  const ProductionBatchLoadRequested(this.batchId);

  @override
  List<Object?> get props => [batchId];
}
