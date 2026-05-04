import 'package:flutter_bloc/flutter_bloc.dart';

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

    // Mark item as printing
    emit(current.copyWith(
      printingItems: {...current.printingItems, event.itemId: true},
    ));

    final result = await _repository.printLabel(
      batchId: event.batchId,
      itemId: event.itemId,
    );

    result.fold(
      (failure) {
        // On API failure, remove from printing state immediately
        final updated = Map<int, bool>.from(current.printingItems)
          ..remove(event.itemId);
        emit(current.copyWith(printingItems: updated));
        emit(LabelingError(failure.message));
        emit(current.copyWith(printingItems: updated));
      },
      (updatedItem) {
        // Replace updated item in list; keep printing state until UI completes
        final updatedItems = current.items.map((i) {
          return i.id == updatedItem.id ? updatedItem : i;
        }).toList();

        emit(LabelingLoaded(
          items: updatedItems,
          printingItems: current.printingItems,
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
