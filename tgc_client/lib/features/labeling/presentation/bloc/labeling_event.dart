import 'package:equatable/equatable.dart';

abstract class LabelingEvent extends Equatable {
  const LabelingEvent();

  @override
  List<Object?> get props => [];
}

class LabelingLoadRequested extends LabelingEvent {
  const LabelingLoadRequested();
}

class LabelingRefreshRequested extends LabelingEvent {
  const LabelingRefreshRequested();
}

class LabelingPrintRequested extends LabelingEvent {
  final int batchId;
  final int itemId;

  const LabelingPrintRequested({required this.batchId, required this.itemId});

  @override
  List<Object?> get props => [batchId, itemId];
}

class LabelingPrintCompleted extends LabelingEvent {
  final int itemId;

  const LabelingPrintCompleted({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}
