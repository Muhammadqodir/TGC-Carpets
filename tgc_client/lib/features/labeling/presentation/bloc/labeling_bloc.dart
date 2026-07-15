import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repositories/labeling_repository.dart';
import 'labeling_event.dart';
import 'labeling_state.dart';

class LabelingBloc extends Bloc<LabelingEvent, LabelingState> {
  final LabelingRepository _repository;

  LabelingBloc({required LabelingRepository repository})
      : _repository = repository,
        super(const LabelingInitial()) {
    on<LabelingLoadRequested>(_onLoadRequested);
    on<LabelingRefreshRequested>(_onRefreshRequested);
    on<LabelingPrintRequested>(_onPrintRequested);
    on<LabelingPrintCompleted>(_onPrintCompleted);
  }

  Future<void> _onLoadRequested(
    LabelingLoadRequested event,
    Emitter<LabelingState> emit,
  ) async {
    emit(const LabelingLoading());
    await _fetchItems(emit);
  }

  Future<void> _onRefreshRequested(
    LabelingRefreshRequested event,
    Emitter<LabelingState> emit,
  ) async {
    emit(const LabelingLoading());
    await _fetchItems(emit);
  }

  Future<void> _onPrintRequested(
    LabelingPrintRequested event,
    Emitter<LabelingState> emit,
  ) async {
    final current = state;
    if (current is! LabelingLoaded) return;

    // If the item is already fully labeled, skip the API call.
    // The label still renders and prints locally.
    final isFullyLabeled = current.items.any(
      (i) => i.id == event.itemId && i.isFullyLabeled,
    );
    if (isFullyLabeled) return;

    // One key per physical label. Generated once at the first tap for this
    // item and reused on every retry, so a network failure followed by the
    // operator tapping Print again resends the same key rather than a fresh
    // one — see instructions/phase-2/02-idempotency-key.md.
    final idempotencyKey =
        current.pendingKeys[event.itemId] ?? const Uuid().v4();

    // Mark item as printing
    emit(current.copyWith(
      printingItems: {...current.printingItems, event.itemId: true},
      pendingKeys: {...current.pendingKeys, event.itemId: idempotencyKey},
    ));

    final result = await _repository.printLabel(
      batchId: event.batchId,
      itemId: event.itemId,
      idempotencyKey: idempotencyKey,
    );

    result.fold(
      (failure) {
        // On API failure, remove from printing state immediately. Keep the
        // pending key so the next tap for this item retries with the same
        // key instead of minting a new one.
        final updated = Map<int, bool>.from(current.printingItems)
          ..remove(event.itemId);
        emit(current.copyWith(printingItems: updated));
        emit(LabelingError(failure.message));
        emit(current.copyWith(printingItems: updated));
      },
      (updatedItem) {
        // Success (including a replay of an already-recorded key): clear
        // the pending key for this item.
        final updatedPendingKeys = Map<int, String>.from(current.pendingKeys)
          ..remove(event.itemId);

        // Replace updated item; remove fully-labeled ones so no network refresh is needed
        final updatedItems = current.items
            .map((i) => i.id == updatedItem.id ? updatedItem : i)
            .where((i) => !i.isFullyLabeled)
            .toList();

        emit(LabelingLoaded(
          items: updatedItems,
          printingItems: current.printingItems,
          pendingKeys: updatedPendingKeys,
        ));
      },
    );
  }

  Future<void> _onPrintCompleted(
    LabelingPrintCompleted event,
    Emitter<LabelingState> emit,
  ) async {
    final current = state;
    if (current is! LabelingLoaded) return;

    final updatedPrinting = Map<int, bool>.from(current.printingItems)
      ..remove(event.itemId);

    emit(current.copyWith(printingItems: updatedPrinting));
  }

  Future<void> _fetchItems(Emitter<LabelingState> emit) async {
    final result = await _repository.getLabelingItems();
    result.fold(
      (failure) => emit(LabelingError(failure.message)),
      (items) => emit(LabelingLoaded(items: items)),
    );
  }
}
