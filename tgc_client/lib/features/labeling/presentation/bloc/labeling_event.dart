import 'package:equatable/equatable.dart';

import '../../domain/entities/labeling_item_entity.dart';

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

/// A label is being rendered and sent to the printer: the card shows a
/// spinner. The count itself goes through LabelPrintQueue.
class LabelingPrintStarted extends LabelingEvent {
  final int itemId;

  const LabelingPrintStarted({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class LabelingPrintCompleted extends LabelingEvent {
  final int itemId;

  const LabelingPrintCompleted({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class LabelingQueueChanged extends LabelingEvent {
  /// The line as the server has it after a label was accepted.
  final LabelingItemEntity? confirmedItem;

  const LabelingQueueChanged({this.confirmedItem});

  @override
  List<Object?> get props => [confirmedItem];
}
