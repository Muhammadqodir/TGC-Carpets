import 'package:equatable/equatable.dart';

import '../../domain/entities/labeling_item_entity.dart';

abstract class LabelingState extends Equatable {
  const LabelingState();

  @override
  List<Object?> get props => [];
}

class LabelingInitial extends LabelingState {
  const LabelingInitial();
}

class LabelingLoading extends LabelingState {
  const LabelingLoading();
}

class LabelingLoaded extends LabelingState {
  final List<LabelingItemEntity> items;

  /// itemId → true while the print-label request is in flight
  final Map<int, bool> printingItems;

  const LabelingLoaded({
    required this.items,
    this.printingItems = const {},
  });

  LabelingLoaded copyWith({
    List<LabelingItemEntity>? items,
    Map<int, bool>? printingItems,
  }) {
    return LabelingLoaded(
      items: items ?? this.items,
      printingItems: printingItems ?? this.printingItems,
    );
  }

  bool isPrinting(int itemId) => printingItems[itemId] == true;

  @override
  List<Object?> get props => [items, printingItems];
}

class LabelingError extends LabelingState {
  final String message;

  const LabelingError(this.message);

  @override
  List<Object?> get props => [message];
}
