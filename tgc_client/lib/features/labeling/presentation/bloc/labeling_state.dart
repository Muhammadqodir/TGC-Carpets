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

  /// itemId → idempotency key for the physical label currently being
  /// printed. Generated once per tap and held here so a retry of the SAME
  /// carpet (network error, then tapping Print again) resends the SAME key
  /// instead of minting a fresh one — otherwise the server-side dedupe in
  /// instructions/phase-2/02-idempotency-key.md protects nothing. Cleared
  /// once the request succeeds.
  final Map<int, String> pendingKeys;

  const LabelingLoaded({
    required this.items,
    this.printingItems = const {},
    this.pendingKeys = const {},
  });

  LabelingLoaded copyWith({
    List<LabelingItemEntity>? items,
    Map<int, bool>? printingItems,
    Map<int, String>? pendingKeys,
  }) {
    return LabelingLoaded(
      items: items ?? this.items,
      printingItems: printingItems ?? this.printingItems,
      pendingKeys: pendingKeys ?? this.pendingKeys,
    );
  }

  bool isPrinting(int itemId) => printingItems[itemId] == true;

  @override
  List<Object?> get props => [items, printingItems, pendingKeys];
}

class LabelingError extends LabelingState {
  final String message;

  const LabelingError(this.message);

  @override
  List<Object?> get props => [message];
}
