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

  /// A replacement for a torn or misprinted label: recorded, not counted.
  final bool reprint;

  const LabelingPrintRequested({
    required this.batchId,
    required this.itemId,
    this.reprint = false,
  });

  @override
  List<Object?> get props => [batchId, itemId, reprint];
}

class LabelingPrintCompleted extends LabelingEvent {
  final int itemId;

  const LabelingPrintCompleted({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}
